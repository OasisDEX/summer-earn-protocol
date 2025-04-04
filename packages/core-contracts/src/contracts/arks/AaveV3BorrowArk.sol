// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";

import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IPriceOracleGetter} from "../../interfaces/aave-v3/IPriceOracleGetter.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "./CarryTradeArk.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FixedPointMathLib} from "@summerfi/dependencies/solmate/src/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";

error InvalidOraclePrice(string asset);
/**
 * @title AaveV3BorrowArk
 * @notice Ark for depositing collateral to Aave V3, borrowing assets, and depositing to yield fleet
 */

abstract contract AaveV3BorrowArk is CarryTradeArk {
    using SafeERC20 for IERC20WithDecimals;
    using FixedPointMathLib for uint256;

    IPoolV3 public immutable aaveV3Pool;
    IRewardsController public immutable rewardsController;
    IPriceOracleGetter public immutable priceOracle;
    address public immutable aToken;
    address public immutable variableDebtToken;

    uint256 public constant ORACLE_BASE = 1e8;

    error EmptyAddress(string service);

    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _poolAddressesProvider,
        address _borrowedAsset,
        address _fleet,
        ArkParams memory _params,
        uint256 _maxLtv
    )
        CarryTradeArk(
            CarryTradeParams({
                _lendingPool: _aaveV3Pool,
                _collateralAsset: _params.asset,
                _borrowedAsset: _borrowedAsset,
                _yieldVault: _fleet,
                _maxLtv: _maxLtv,
                baseParams: _params
            })
        )
    {
        if (_aaveV3Pool == address(0)) {
            revert EmptyAddress("aave v3 pool");
        }
        aaveV3Pool = IPoolV3(_aaveV3Pool);

        if (_rewardsController == address(0)) {
            revert EmptyAddress("rewards controller");
        }
        rewardsController = IRewardsController(_rewardsController);

        if (_poolAddressesProvider == address(0)) {
            revert EmptyAddress("pool addresses provider");
        }

        IPoolAddressesProvider poolAddressesProvider = IPoolAddressesProvider(
            _poolAddressesProvider
        );
        address priceOracleAddress = poolAddressesProvider.getPriceOracle();
        if (priceOracleAddress == address(0)) {
            revert EmptyAddress("price oracle");
        }
        priceOracle = IPriceOracleGetter(priceOracleAddress);
        aToken = IPoolV3(_aaveV3Pool)
            .getReserveData(_params.asset)
            .aTokenAddress;
        variableDebtToken = IPoolV3(_aaveV3Pool)
            .getReserveData(_borrowedAsset)
            .variableDebtTokenAddress;
    }

    function _totalAssets() internal view override returns (uint256) {
        // total assets is the worth of collateral in the borrowed asset
        // minus the debt in the borrowed asset
        // plus the amount deposited to the fleet
        uint256 collateralValue = _getCollateralValueInBorrowedAsset();
        uint256 debt = _getTotalDebt();
        uint256 shares = IERC4626(yieldVault).balanceOf(address(this));
        uint256 yieldVaultValue = IERC4626(yieldVault).convertToAssets(shares);
        return collateralValue + yieldVaultValue - debt;
    }

    function _supplyCollateral(uint256 amount) internal override {
        collateralAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(collateralAsset), amount, address(this), 0);
    }

    function _getCurrentLtv() internal view override returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            ,
            ,

        ) = aaveV3Pool.getUserAccountData(address(this));
        if (totalCollateralBase == 0) {
            return 0;
        }
        // Calculate the loan-to-value (LTV) ratio for Aave V3
        // LTV is the ratio of the total debt to the total collateral, expressed as a percentage
        // The result is multiplied by 10000 to preserve precision
        // eg 0.67 (67%) LTV is stored as 6700
        uint256 ltv = totalDebtBase.mulDivUp(BASIS_POINTS, totalCollateralBase);

        return ltv;
    }

    function _getCollateralValueInBorrowedAsset()
        internal
        view
        override
        returns (uint256)
    {
        uint256 collateralAmount = _getTotalCollateral(); // Amount of aTokens (same decimals as underlying collateral)
        if (collateralAmount == 0) {
            return 0;
        }

        // Get asset prices in the oracle's base currency (e.g., USD with 8 decimals)
        uint256 collateralPrice = priceOracle.getAssetPrice(
            address(collateralAsset)
        );
        uint256 borrowedPrice = priceOracle.getAssetPrice(
            address(borrowedAsset)
        );

        // Validate oracle prices
        if (collateralPrice == 0) revert InvalidOraclePrice("Collateral");
        if (borrowedPrice == 0) revert InvalidOraclePrice("Borrowed");

        // Get asset decimals
        uint256 collateralDecimals = collateralAsset.decimals();
        uint256 borrowedDecimals = borrowedAsset.decimals();

        // Calculate required decimal scaling factors
        uint256 collateralUnit = 10 ** collateralDecimals;
        uint256 borrowedUnit = 10 ** borrowedDecimals;

        // Perform calculation using FixedPointMathLib for precision and safety.
        // Formula: (collateralAmount * collateralPrice / borrowedPrice) * (borrowedUnit / collateralUnit)
        // We use chained mulDiv to prevent intermediate overflows/underflows.
        // result = collateralAmount * (collateralPrice / borrowedPrice) * (10**borrowedDecimals /
        // 10**collateralDecimals)
        // Step 1: Calculate value ratio adjusted for collateral amount
        // intermediate = (collateralAmount * collateralPrice) / borrowedPrice
        uint256 intermediateValue = collateralAmount.mulDivDown(
            collateralPrice,
            borrowedPrice
        );

        // Step 2: Adjust decimals from collateralDecimals to borrowedDecimals
        // finalValue = intermediateValue * (10**borrowedDecimals) / (10**collateralDecimals)
        // Use standard rounding mulDiv.
        uint256 collateralValueInBorrowedAsset = intermediateValue.mulDivDown(
            borrowedUnit,
            collateralUnit
        );

        return collateralValueInBorrowedAsset;
    }

    function _getTotalDebt() internal view override returns (uint256) {
        return IERC20WithDecimals(variableDebtToken).balanceOf(address(this));
    }

    function _getTotalCollateral() internal view override returns (uint256) {
        return IERC20WithDecimals(aToken).balanceOf(address(this));
    }

    function _borrowAsset(uint256 amount) internal override {
        aaveV3Pool.borrow(
            address(borrowedAsset),
            amount,
            2, // variable rate
            0,
            address(this)
        );
    }

    function _depositToYieldVault(uint256 amount) internal override {
        borrowedAsset.forceApprove(yieldVault, amount);
        IERC4626(yieldVault).deposit(amount, address(this));
    }

    function _withdrawFromYieldVault(uint256 amount) internal override {
        IERC4626(yieldVault).withdraw(amount, address(this), address(this));
    }

    function _repayBorrow(uint256 amount) internal override {
        borrowedAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.repay(address(borrowedAsset), amount, 2, address(this));
    }

    function _withdrawCollateral(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(collateralAsset), amount, address(this));
    }

    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address[] memory assets = new address[](2);
        assets[0] = aToken;
        assets[1] = variableDebtToken;

        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);

        try rewardsController.claimAllRewards(assets, address(this)) returns (
            address[] memory tokens,
            uint256[] memory amounts
        ) {
            rewardTokens = tokens;
            rewardAmounts = amounts;
        } catch {
            // If claiming rewards fails, return empty arrays
        }
    }
}
