// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Ark.sol";
import {console} from "forge-std/console.sol";
import {FixedPointMathLib} from "@summerfi/dependencies/solmate/src/utils/FixedPointMathLib.sol";

interface IERC20WithDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title CarryTradeArk
 * @notice Base contract for implementing carry trade strategies using lending protocols
 * @dev This abstract contract provides the foundation for carry trade implementations
 */
abstract contract CarryTradeArk is Ark {
    using SafeERC20 for IERC20WithDecimals;
    using FixedPointMathLib for uint256;

    // Common state variables for carry trades
    IERC20WithDecimals public immutable collateralAsset;
    IERC20WithDecimals public immutable borrowedAsset;
    address public immutable yieldVault;

    // Protocol-specific storage
    address public immutable lendingPool;

    // Add new state variables for LTV management
    uint256 public immutable maxLtv; // Maximum LTV in basis points (e.g., 7500 = 75%)
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SAFETY_MARGIN = 100; // 1% safety margin below maxLtv

    struct CarryTradeParams {
        address _lendingPool;
        address _collateralAsset;
        address _borrowedAsset;
        address _yieldVault;
        uint256 _maxLtv; // Add maxLtv parameter
        ArkParams baseParams;
    }
    error InvalidMaxLtv(uint256 maxLtv);
    constructor(CarryTradeParams memory params) Ark(params.baseParams) {
        lendingPool = params._lendingPool;
        collateralAsset = IERC20WithDecimals(params._collateralAsset);
        borrowedAsset = IERC20WithDecimals(params._borrowedAsset);
        yieldVault = params._yieldVault;
        if (params._maxLtv == 0 || params._maxLtv > BASIS_POINTS) {
            revert InvalidMaxLtv(params._maxLtv);
        }
        maxLtv = params._maxLtv;
    }

    /**
     * @notice Returns total assets (collateral) deposited in the lending protocol
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _totalAssets();
    }

    /**
     * @notice Checks if the position's LTV is safe
     * @return bool True if the position is safe
     */
    function isPositionSafe() public view returns (bool) {
        return _getCurrentLtv() <= maxLtv;
    }
    function currentLtv() public view returns (uint256) {
        return _getCurrentLtv();
    }
    /**
     * @notice Rebalances the position to maintain safe LTV
     * @dev Withdraws from yield vault and repays debt if necessary
     */
    function rebalancePosition() external {
        uint256 currentLtv = _getCurrentLtv();
        if (currentLtv <= maxLtv - SAFETY_MARGIN) return; // Position is safe enough

        uint256 totalDebt = _getTotalDebt();
        uint256 collateralValue = _getCollateralValueInBorrowedAsset();

        // Calculate how much debt to repay to reach target LTV using FixedPointMathLib
        uint256 targetLtv = maxLtv - SAFETY_MARGIN;
        uint256 targetDebt = collateralValue.mulDivDown(
            targetLtv,
            BASIS_POINTS
        );
        uint256 repayAmount = totalDebt - targetDebt;

        // Withdraw from yield vault and repay
        _withdrawFromYieldVault(repayAmount);
        _repayBorrow(repayAmount);

        emit PositionRebalanced(repayAmount, _getCurrentLtv());
    }

    /**
     * @notice Executes the carry trade by depositing collateral, borrowing assets, and depositing into yield vault
     * @param amount Amount of collateral to deposit
     * @param data Encoded borrow parameters (e.g. borrow amount)
     */
    function _board(
        uint256 amount,
        bytes calldata data
    ) internal virtual override {
        uint256 borrowAmount = abi.decode(data, (uint256));

        // Step 1: Supply collateral to lending protocol
        _supplyCollateral(amount);

        // Step 2: Borrow the target asset
        _borrowAsset(borrowAmount);

        // Step 3: Deposit borrowed assets into yield-generating vault
        _depositToYieldVault(borrowAmount);
    }

    /**
     * @notice Unwinds the carry trade position
     * @param amount Amount of collateral to withdraw
     * @param data Encoded repayment parameters
     */
    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal virtual override {
        uint256 repayAmount = abi.decode(data, (uint256));

        // Step 1: Withdraw from yield vault
        _withdrawFromYieldVault(repayAmount);

        // Step 2: Repay borrowed assets
        _repayBorrow(repayAmount);

        // Step 3: Withdraw collateral
        _withdrawCollateral(amount);
    }

    // Abstract internal functions that must be implemented by specific protocol integrations
    function _supplyCollateral(uint256 amount) internal virtual;
    function _borrowAsset(uint256 amount) internal virtual;
    function _depositToYieldVault(uint256 amount) internal virtual;
    function _withdrawFromYieldVault(uint256 amount) internal virtual;
    function _repayBorrow(uint256 amount) internal virtual;
    function _withdrawCollateral(uint256 amount) internal virtual;
    function _getTotalDebt() internal view virtual returns (uint256);
    function _getTotalCollateral() internal view virtual returns (uint256);
    function _getCurrentLtv() internal view virtual returns (uint256);

    /**
     * @notice Basic validation for carry trade parameters
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        if (data.length != 32) {
            revert("Invalid borrow amount encoding");
        }
    }

    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        if (data.length != 32) {
            revert("Invalid repay amount encoding");
        }
    }

    function _withdrawableTotalAssets()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return totalAssets();
    }

    function _totalAssets() internal view virtual returns (uint256);

    /**
     * @notice Claims any additional rewards from both lending protocol and yield vault
     * @dev Should be implemented by specific protocol integrations to handle their reward mechanisms
     */
    function _harvest(
        bytes calldata
    )
        internal
        virtual
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts);

    /**
     * @notice Calculates the value of collateral in terms of borrowed asset
     * @return Value of collateral in borrowed asset terms
     */
    function _getCollateralValueInBorrowedAsset()
        internal
        view
        virtual
        returns (uint256);

    // Add event for position rebalancing
    event PositionRebalanced(uint256 repayAmount, uint256 newLtv);
}
