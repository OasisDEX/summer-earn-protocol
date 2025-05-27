// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ICarryTradeArk} from "../../interfaces/ICarryTradeArk.sol";
import {IFleetCommander} from "../../interfaces/IFleetCommander.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FixedPointMathLib} from "@summerfi/dependencies/solmate/src/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20WithDecimals} from "../../interfaces/ICarryTradeArk.sol";

/**
 * @title CarryTradeArk
 * @notice Base contract for implementing carry trade strategies using lending protocols
 * @dev This abstract contract provides the foundation for carry trade implementations
 */
abstract contract CarryTradeArk is Ark, ICarryTradeArk {
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
    uint256 public slippage;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SAFETY_MARGIN = 100; // 1% safety margin below maxLtv
    uint256 public constant MAX_SLIPPAGE = 1000; // 10%
    /// @notice whitelisted routers
    mapping(address router => bool isWhitelisted) public whitelistedRouters;

    constructor(CarryTradeParams memory params) Ark(params.baseParams) {
        lendingPool = params._lendingPool;
        if (params._collateralAsset == params._borrowedAsset) {
            revert CollateralAndBorrowedAssetCannotBeTheSame();
        }
        if (
            params._collateralAsset == address(0) ||
            params._borrowedAsset == address(0)
        ) {
            revert InvalidAsset();
        }
        if (params._collateralAsset != params.baseParams.asset) {
            revert CollateralAssetDoesNotMatchBaseAsset();
        }

        collateralAsset = IERC20WithDecimals(params._collateralAsset);
        borrowedAsset = IERC20WithDecimals(params._borrowedAsset);
        yieldVault = params._yieldVault;
        if (params._maxLtv == 0 || params._maxLtv > BASIS_POINTS) {
            revert InvalidMaxLtv(params._maxLtv);
        }
        maxLtv = params._maxLtv;
        slippage = params._slippage;
    }

    /**
     * @notice Returns total assets (collateral) deposited in the lending protocol
     */
    function totalAssets() public view virtual override(Ark, IArk) returns (uint256) {
        return _totalAssets();
    }

    /**
     * @notice Checks if the position's LTV is safe
     * @return bool True if the position is safe
     */
    function isPositionSafe() public view returns (bool) {
        return _getCurrentLtv() <= maxLtv;
    }

    function currentLtv() public view override returns (uint256) {
        return _getCurrentLtv();
    }
    
    function totalDebt() public view override returns (uint256) {
        return _getTotalDebt();
    }
    
    function totalCollateral() public view override returns (uint256) {
        return _getTotalCollateral();
    }
    
    function yieldVaultBalance() public view override returns (uint256) {
        uint256 shares = IERC4626(yieldVault).balanceOf(address(this));
        return IERC4626(yieldVault).convertToAssets(shares);
    }

    function whitelistRouter(
        address router,
        bool isWhitelisted
    ) external onlyCurator(config.commander) {
        whitelistedRouters[router] = isWhitelisted;
        emit RouterWhitelisted(router, isWhitelisted);
    }

    function setSlippage(
        uint256 _slippage
    ) external onlyCurator(config.commander) {
        if (_slippage > MAX_SLIPPAGE) {
            revert SlippageTooHigh();
        }
        slippage = _slippage;
        emit SlippageSet(_slippage);
    }

    /**
     * @notice Rebalances the position to maintain safe LTV
     * @dev Withdraws from yield vault and repays debt if necessary
     */
    function _rebalancePosition() internal {
        uint256 currentLtvValue = _getCurrentLtv();
        // uint256 assetBalance = collateralAsset.balanceOf(address(this));
        // if (assetBalance > 0) {
        //     _supplyCollateral(assetBalance);
        // }
        if (currentLtvValue <= maxLtv - SAFETY_MARGIN) return; // Position is safe enough
        uint256 totalDebtAmount = _getTotalDebt();
        uint256 collateralValue = _getCollateralValueInBorrowedAsset(
            _getTotalCollateral()
        );

        // Calculate how much debt to repay to reach target LTV using FixedPointMathLib
        uint256 targetLtv = maxLtv - SAFETY_MARGIN;
        uint256 targetDebt = collateralValue.mulDivDown(
            targetLtv,
            BASIS_POINTS
        );
        uint256 repayAmount = totalDebtAmount - targetDebt;
        // Withdraw from yield vault and repay
        _withdrawFromYieldVault(repayAmount);
        _repayBorrow(repayAmount);

        emit PositionRebalanced(repayAmount, _getCurrentLtv());
    }

    function upkeep(bytes calldata upkeepData) external override onlyKeeper {
        UpkeepData memory params = abi.decode(upkeepData, (UpkeepData));
        
        if (params.action == UpkeepAction.REBALANCE) {
            _rebalancePosition();
        } else if (params.action == UpkeepAction.COMPOUND) {
            _compound();
        } else if (params.action == UpkeepAction.EMERGENCY_EXIT) {
            SwapData memory swapData = abi.decode(params.actionData, (SwapData));
            _emergencyExit(swapData);
        }
    }
    
    function emergencyExit(bytes calldata swapData) external override onlyKeeper {
        SwapData memory swap = abi.decode(swapData, (SwapData));
        _emergencyExit(swap);
    }
    
    function compound() external override onlyKeeper {
        _compound();
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

        // Step 4: Rebalance position
        _rebalancePosition();
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
        DisembarkData memory disembarkData = abi.decode(data, (DisembarkData));
        uint256 repayAmount = disembarkData.repayAmount;

        if (!disembarkData.closePosition) {
            // Step 1: Withdraw from yield vault
            _withdrawFromYieldVault(repayAmount);

            // Step 2: Repay borrowed assets
            _repayBorrow(repayAmount);

            // Step 3: Withdraw collateral
            _withdrawCollateral(amount);

            // Step 4: Rebalance position
            _rebalancePosition();
        } else {
            // Step 1: Withdraw all from yield vault
            _withdrawAllFromYieldVault();

            // Step 2: Close position
            _closePosition();

            // Step 3: Sweep borrowed dust
            _sweepBorrowedDust(disembarkData.swapData);

            // Step 4: Sweep collateral dust
            _sweepCollateralDust(amount);
        }
    }

    // Abstract internal functions that must be implemented by specific protocol integrations
    function _supplyCollateral(uint256 amount) internal virtual;
    function _borrowAsset(uint256 amount) internal virtual;
    function _repayBorrow(uint256 amount) internal virtual;
    function _withdrawCollateral(uint256 amount) internal virtual;
    function _getTotalDebt() internal view virtual returns (uint256);
    function _getTotalCollateral() internal view virtual returns (uint256);
    function _getCurrentLtv() internal view virtual returns (uint256);
    function _closePosition() internal virtual;

    function _sweepBorrowedDust(SwapData memory swapData) internal {
        uint256 borrowedAssetBalance = borrowedAsset.balanceOf(address(this));
        if (borrowedAssetBalance == 0 || swapData.router == address(0)) {
            return; // Nothing to swap
        }
        
        _swap(
            address(borrowedAsset),
            address(collateralAsset),
            swapData.router,
            borrowedAssetBalance,
            swapData.minAmountOut,
            swapData.swapCalldata
        );
    }
    function _sweepCollateralDust(uint256 disembarkAmount) internal {
        uint256 assetBalance = collateralAsset.balanceOf(address(this));
        if (assetBalance > disembarkAmount) {
            address bufferArk = IFleetCommander(config.commander).bufferArk();
            collateralAsset.forceApprove(
                bufferArk,
                assetBalance - disembarkAmount
            );
            IArk(bufferArk).board(assetBalance - disembarkAmount, "");
        }
    }
    /**
     * @notice Basic validation for carry trade parameters
     */
    function _validateBoardData(bytes calldata data) internal pure override {
        if (data.length != 32) {
            revert InvalidBorrowAmountEncoding();
        }
    }

    function _validateDisembarkData(
        bytes calldata data
    ) internal pure override {
        DisembarkData memory disembarkData = abi.decode(data, (DisembarkData));
        if (!disembarkData.closePosition && disembarkData.repayAmount == 0) {
            revert InvalidRepayAmount();
        }
        if (disembarkData.closePosition && disembarkData.swapData.router == address(0)) {
            revert InvalidRouterForClosePosition();
        }
        if (disembarkData.closePosition && disembarkData.swapData.swapCalldata.length == 0) {
            revert InvalidSwapCalldataForClosePosition();
        }
    }

    function _withdrawableTotalAssets()
        internal
        view
        virtual
        override
        returns (uint256)
    {
        return 0;
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
     * @param collateralAmount The amount of collateral to calculate the value of
     * @return Value of collateral in borrowed asset terms
     */
    function _getCollateralValueInBorrowedAsset(
        uint256 collateralAmount
    ) internal view virtual returns (uint256);

    function _depositToYieldVault(uint256 amount) internal {
        borrowedAsset.forceApprove(yieldVault, amount);
        IERC4626(yieldVault).deposit(amount, address(this));
    }

    function _withdrawFromYieldVault(uint256 amount) internal {
        IERC4626(yieldVault).withdraw(amount, address(this), address(this));
    }

    function _withdrawAllFromYieldVault() internal {
        IERC4626(yieldVault).redeem(
            IERC4626(yieldVault).balanceOf(address(this)),
            address(this),
            address(this)
        );
    }

    function _swap(
        address sellToken,
        address buyToken,
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes memory swapCalldata
    ) internal returns (uint256 amountOut) {
        if (!whitelistedRouters[router]) {
            revert RouterNotWhitelisted(router);
        }
        IERC20(sellToken).approve(router, amountIn);
        uint256 buyTokenBalanceBefore = IERC20(buyToken).balanceOf(
            address(this)
        );
        Address.functionCall(router, swapCalldata);
        uint256 buyTokenBalanceAfter = IERC20(buyToken).balanceOf(
            address(this)
        );
        amountOut = buyTokenBalanceAfter - buyTokenBalanceBefore;
        if (amountOut < amountOutMin) {
            revert ReceivedLessThanExpected();
        }
        emit Swapped(sellToken, router, amountIn, swapCalldata);
    }

    /**
     * @notice Applies slippage to the amount
     * @param amount The amount to apply slippage to
     * @return amountWithSlippage The amount after applying slippage
     */
    function _applySlippage(
        uint256 amount
    ) internal view returns (uint256 amountWithSlippage) {
        amountWithSlippage =
            (amount * (BASIS_POINTS - slippage)) /
            BASIS_POINTS;
    }
    
    function _compound() internal {
        // Check if we have room to borrow more
        uint256 currentLtvValue = _getCurrentLtv();
        if (currentLtvValue >= maxLtv - SAFETY_MARGIN) {
            revert PositionUnsafe(currentLtvValue, maxLtv);
        }
        
        // Calculate how much more we can borrow
        uint256 collateralValue = _getCollateralValueInBorrowedAsset(_getTotalCollateral());
        uint256 currentDebt = _getTotalDebt();
        uint256 maxDebt = collateralValue.mulDivDown(maxLtv - SAFETY_MARGIN, BASIS_POINTS);
        uint256 additionalBorrow = maxDebt - currentDebt;
        
        if (additionalBorrow > 0) {
            _borrowAsset(additionalBorrow);
            _depositToYieldVault(additionalBorrow);
            emit PositionCompounded(additionalBorrow, _getCurrentLtv());
        }
    }
    
    function _emergencyExit(SwapData memory swapData) internal {
        // 1. Withdraw everything from yield vault
        uint256 totalInVault = yieldVaultBalance();
        if (totalInVault > 0) {
            _withdrawAllFromYieldVault();
        }
        
        // 2. Repay as much debt as possible
        uint256 debt = _getTotalDebt();
        uint256 borrowedBalance = borrowedAsset.balanceOf(address(this));
        uint256 repayAmount = borrowedBalance > debt ? debt : borrowedBalance;
        
        if (repayAmount > 0) {
            _repayBorrow(repayAmount);
        }
        
        // 3. Swap remaining borrowed asset to collateral if needed
        uint256 remainingBorrowed = borrowedAsset.balanceOf(address(this));
        if (remainingBorrowed > 0 && swapData.router != address(0)) {
            _swap(
                address(borrowedAsset),
                address(collateralAsset),
                swapData.router,
                remainingBorrowed,
                swapData.minAmountOut,
                swapData.swapCalldata
            );
        }
        
        // 4. Withdraw all collateral
        uint256 collateralAmount = _getTotalCollateral();
        if (collateralAmount > 0) {
            _withdrawCollateral(collateralAmount);
        }
        
        // 5. Send all assets to buffer
        uint256 finalBalance = collateralAsset.balanceOf(address(this));
        if (finalBalance > 0) {
            address bufferArk = IFleetCommander(config.commander).bufferArk();
            collateralAsset.safeTransfer(bufferArk, finalBalance);
        }
        
        emit EmergencyExit(finalBalance, debt > borrowedBalance ? debt - borrowedBalance : 0);
    }
}
