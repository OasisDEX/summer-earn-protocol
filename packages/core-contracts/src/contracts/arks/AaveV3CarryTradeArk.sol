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
 * @title AaveV3CarryTradeArk
 * @notice Ark for depositing collateral to Aave V3, borrowing assets, and depositing to yield fleet
 */

contract AaveV3CarryTradeArk is CarryTradeArk {
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
        uint256 _maxLtv,
        uint256 _slippage,
        ArkParams memory _params
    )
        CarryTradeArk(
            CarryTradeParams({
                _lendingPool: _aaveV3Pool,
                _collateralAsset: _params.asset,
                _borrowedAsset: _borrowedAsset,
                _yieldVault: _fleet,
                _maxLtv: _maxLtv,
                _slippage: _slippage,
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

    /**
     * @notice Calculates the total assets under management by the Ark
     * @dev This function overrides the base implementation to account for Aave V3 specific calculations
     * @return The total value of assets in collateral terms, including:
     *         - Collateral deposited in Aave V3
     *         - Net value from yield position (yield vault balance - debt)
     *         - Profits/losses converted to collateral terms
     */
    function _totalAssets() internal view override returns (uint256) {
        // Get collateral amount
        uint256 collateralAmount = _getTotalCollateral();

        // Get net value from yield position (yield vault balance - debt) in borrowed asset terms
        uint256 yieldVaultBalance = IERC4626(yieldVault).convertToAssets(
            IERC4626(yieldVault).balanceOf(address(this))
        );
        uint256 debt = _getTotalDebt();

        if (yieldVaultBalance >= debt) {
            // Profitable position - convert profit to collateral terms
            uint256 profitInBorrowedAsset = yieldVaultBalance - debt;
            uint256 profitInCollateral = _convertBorrowedToCollateral(
                profitInBorrowedAsset
            );
            return collateralAmount + profitInCollateral;
        } else {
            // Loss position - reduce collateral value
            uint256 lossInBorrowedAsset = debt - yieldVaultBalance;
            uint256 lossInCollateral = _convertBorrowedToCollateral(
                lossInBorrowedAsset
            );
            return
                collateralAmount > lossInCollateral
                    ? collateralAmount - lossInCollateral
                    : 0;
        }
    }

    /**
     * @notice Supplies collateral to Aave V3 lending pool
     * @dev Approves and supplies the specified amount of collateral to Aave V3
     * @param amount The amount of collateral to supply
     */
    function _supplyCollateral(uint256 amount) internal override {
        collateralAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(collateralAsset), amount, address(this), 0);
    }

    /**
     * @notice Calculates the current loan-to-value (LTV) ratio for the position
     * @dev Uses Aave V3's getUserAccountData to get collateral and debt values
     * @return The current LTV ratio in basis points (e.g., 7500 = 75%)
     */
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

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts an amount from borrowed asset to collateral terms
     * @dev Uses Aave V3's price oracle to get asset prices and performs precise calculations
     * @param borrowedAssetAmount The amount in borrowed asset terms
     * @return The equivalent amount in collateral terms
     */
    function _convertBorrowedToCollateral(
        uint256 borrowedAssetAmount
    ) internal view returns (uint256) {
        // Get asset prices in the oracle's base currency (e.g., USD with 8 decimals)
        uint256 collateralPrice = priceOracle.getAssetPrice(
            address(collateralAsset)
        );
        uint256 borrowedPrice = priceOracle.getAssetPrice(
            address(borrowedAsset)
        );

        // Calculate required decimal scaling factors
        uint256 collateralUnit = 10 ** collateralAsset.decimals();
        uint256 borrowedUnit = 10 ** borrowedAsset.decimals();

        // Perform calculation using FixedPointMathLib for precision and safety.
        // Formula: (borrowedAssetAmount * borrowedPrice / collateralPrice) * (collateralUnit / borrowedUnit)
        // We use chained mulDiv to prevent intermediate overflows/underflows.

        // Step 1: Calculate value ratio adjusted for collateral amount
        // intermediate = (borrowedAssetAmount * borrowedPrice) / collateralPrice
        uint256 intermediateValue = borrowedAssetAmount.mulDivDown(
            borrowedPrice,
            collateralPrice
        );

        // Step 2: Adjust decimals from collateralDecimals to borrowedDecimals
        // finalValue = intermediateValue * (10**collateralDecimals) / (10**borrowedDecimals)
        // Use standard rounding mulDiv.
        uint256 collateralValueInBorrowedAsset = intermediateValue.mulDivDown(
            collateralUnit,
            borrowedUnit
        );

        return collateralValueInBorrowedAsset;
    }

    /**
     * @notice Calculates the value of collateral in borrowed asset terms
     * @dev Uses Aave V3's price oracle to get asset prices and performs precise calculations
     * @param collateralAmount The amount of collateral to convert
     * @return The equivalent value in borrowed asset terms
     */
    function _getCollateralValueInBorrowedAsset(
        uint256 collateralAmount
    ) internal view override returns (uint256) {
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

    /**
     * @notice Gets the total debt in borrowed asset
     * @dev Reads the balance of the variable debt token
     * @return The total debt amount
     */
    function _getTotalDebt() internal view override returns (uint256) {
        return IERC20WithDecimals(variableDebtToken).balanceOf(address(this));
    }

    /**
     * @notice Gets the total collateral deposited in Aave V3
     * @dev Reads the balance of the aToken
     * @return The total collateral amount
     */
    function _getTotalCollateral() internal view override returns (uint256) {
        return IERC20WithDecimals(aToken).balanceOf(address(this));
    }

    /**
     * @notice Borrows assets from Aave V3 lending pool
     * @dev Borrows the specified amount at variable rate
     * @param amount The amount to borrow
     */
    function _borrowAsset(uint256 amount) internal override {
        aaveV3Pool.borrow(
            address(borrowedAsset),
            amount,
            2, // variable rate
            0,
            address(this)
        );
    }

    /**
     * @notice Closes the entire position in Aave V3
     * @dev Repays all debt and withdraws all collateral
     */
    function _closePosition() internal override {
        _repayBorrow(_getTotalDebt());
        _withdrawCollateral(_getTotalCollateral());
    }

    /**
     * @notice Repays borrowed assets to Aave V3 lending pool
     * @dev Approves and repays the specified amount
     * @param amount The amount to repay
     */
    function _repayBorrow(uint256 amount) internal override {
        borrowedAsset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.repay(address(borrowedAsset), amount, 2, address(this));
    }

    /**
     * @notice Withdraws collateral from Aave V3 lending pool
     * @dev Withdraws the specified amount of collateral
     * @param amount The amount to withdraw
     */
    function _withdrawCollateral(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(collateralAsset), amount, address(this));
    }

    /**
     * @notice Harvests rewards from Aave V3 positions
     * @dev Claims rewards for both collateral and debt positions
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of reward amounts corresponding to rewardTokens
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = aToken;

        (rewardTokens, rewardAmounts) = rewardsController.claimAllRewards(
            incentivizedAssets,
            raft()
        );

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }
}
