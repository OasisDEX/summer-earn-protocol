// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Ark.sol";

/**
 * @title CarryTradeArk
 * @notice Base contract for implementing carry trade strategies using lending protocols
 * @dev This abstract contract provides the foundation for carry trade implementations
 */
abstract contract CarryTradeArk is Ark {
    using SafeERC20 for IERC20;

    // Common state variables for carry trades
    IERC20 public immutable collateralAsset;
    IERC20 public immutable borrowedAsset;
    address public immutable yieldVault;

    // Protocol-specific storage
    address public immutable lendingPool;
    address public immutable collateralToken; // e.g., aToken
    address public immutable debtToken;

    struct CarryTradeParams {
        address _lendingPool;
        address _collateralAsset;
        address _borrowedAsset;
        address _yieldVault;
        address _collateralToken;
        address _debtToken;
        ArkParams baseParams;
    }

    constructor(CarryTradeParams memory params) Ark(params.baseParams) {
        lendingPool = params._lendingPool;
        collateralAsset = IERC20(params._collateralAsset);
        borrowedAsset = IERC20(params._borrowedAsset);
        yieldVault = params._yieldVault;
        collateralToken = params._collateralToken;
        debtToken = params._debtToken;
    }

    /**
     * @notice Returns total assets (collateral) deposited in the lending protocol
     */
    function totalAssets() public view virtual override returns (uint256) {
        return IERC20(collateralToken).balanceOf(address(this));
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

    /**
     * @notice Basic validation for carry trade parameters
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        require(data.length == 32, "Invalid borrow amount encoding");
    }

    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        require(data.length == 32, "Invalid repay amount encoding");
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
}
