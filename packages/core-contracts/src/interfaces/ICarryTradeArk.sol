// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "./IArk.sol";
import {ArkParams} from "../types/ArkTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC20WithDecimals
 * @notice Interface for ERC20 tokens with decimals information
 * @dev Extends IERC20 to include decimals() function
 */
interface IERC20WithDecimals is IERC20 {
    /**
     * @notice Returns the number of decimals used to get its user representation
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);
}

/**
 * @title ICarryTradeArk
 * @notice Interface for Arks that implement carry trade strategies
 * @dev Extends IArk with carry trade specific functionality. Carry trade strategies involve:
 *      1. Depositing collateral to a lending protocol
 *      2. Borrowing assets against the collateral
 *      3. Depositing borrowed assets to a yield vault
 *      4. Managing the position through rebalancing and compounding
 */
interface ICarryTradeArk is IArk {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the maximum LTV is set to an invalid value
    error InvalidMaxLtv(uint256 maxLtv);
    /// @notice Thrown when the current LTV exceeds the maximum allowed LTV
    error PositionUnsafe(uint256 currentLtv, uint256 maxLtv);
    /// @notice Thrown when swap data is invalid or malformed
    error InvalidSwapData();
    /// @notice Thrown when a swap operation fails
    error SwapFailed();
    /// @notice Thrown when attempting partial withdrawals, which are not supported
    error PartialWithdrawalsNotAllowed();
    /// @notice Thrown when there is insufficient profit to perform an operation
    error InsufficientProfit();
    /// @notice Thrown when attempting to use a non-whitelisted router
    error RouterNotWhitelisted(address router);
    /// @notice Thrown when the slippage tolerance is too high
    error SlippageTooHigh();
    /// @notice Thrown when collateral and borrowed assets are the same
    error CollateralAndBorrowedAssetCannotBeTheSame();
    /// @notice Thrown when an invalid asset is provided
    error InvalidAsset();
    /// @notice Thrown when collateral asset doesn't match the base asset
    error CollateralAssetDoesNotMatchBaseAsset();
    /// @notice Thrown when received amount is less than expected
    error ReceivedLessThanExpected();
    /// @notice Thrown when borrow amount encoding is invalid
    error InvalidBorrowAmountEncoding();
    /// @notice Thrown when repay amount is invalid
    error InvalidRepayAmount();
    /// @notice Thrown when an invalid router is used for closing position
    error InvalidRouterForClosePosition();
    /// @notice Thrown when swap calldata is invalid for closing position
    error InvalidSwapCalldataForClosePosition();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a position is rebalanced
    event PositionRebalanced(uint256 repayAmount, uint256 newLtv);
    /// @notice Emitted during emergency exit, showing recovered collateral and losses
    event EmergencyExit(uint256 collateralRecovered, uint256 loss);
    /// @notice Emitted when position is compounded with additional borrowing
    event PositionCompounded(uint256 additionalBorrowed, uint256 newLtv);
    /// @notice Emitted when a router is whitelisted or removed from whitelist
    event RouterWhitelisted(address router, bool whitelisted);
    /// @notice Emitted when assets are swapped
    event Swapped(
        address sellToken,
        address router,
        uint256 amountIn,
        bytes swapCalldata
    );
    /// @notice Emitted when slippage tolerance is updated
    event SlippageSet(uint256 slippage);

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Enum defining possible upkeep actions
     */
    enum UpkeepAction {
        REBALANCE, /// @dev Rebalance the position to maintain target LTV
        COMPOUND, /// @dev Compound profits by borrowing more
        EMERGENCY_EXIT /// @dev Emergency exit from the position
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Parameters required for initializing a carry trade position
     * @param _lendingPool Address of the lending pool
     * @param _collateralAsset Address of the collateral asset
     * @param _borrowedAsset Address of the borrowed asset
     * @param _yieldVault Address of the yield vault
     * @param _maxLtv Maximum allowed LTV in basis points
     * @param _slippage Slippage tolerance in basis points
     * @param baseParams Base Ark parameters
     */
    struct CarryTradeParams {
        address _lendingPool;
        address _collateralAsset;
        address _borrowedAsset;
        address _yieldVault;
        uint256 _maxLtv;
        uint256 _slippage;
        ArkParams baseParams;
    }

    /**
     * @notice Data structure for upkeep operations
     * @param action The type of upkeep action to perform
     * @param actionData Additional data required for the action
     */
    struct UpkeepData {
        UpkeepAction action;
        bytes actionData;
    }

    /**
     * @notice Data structure for swap operations
     * @param router Address of the router to use for the swap
     * @param swapCalldata Calldata for the swap operation
     * @param minAmountOut Minimum amount expected from the swap
     */
    struct SwapData {
        address router;
        bytes swapCalldata;
        uint256 minAmountOut;
    }

    /**
     * @notice Data structure for disembark operations
     * @param closePosition Whether to close the position
     * @param repayAmount Amount to repay when closing position
     * @param swapData Swap data for converting remaining assets
     */
    struct DisembarkData {
        bool closePosition;
        uint256 repayAmount;
        SwapData swapData;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the current loan-to-value ratio
     * @return Current LTV in basis points (e.g., 7500 = 75%)
     */
    function currentLtv() external view returns (uint256);

    /**
     * @notice Returns the maximum allowed LTV
     * @return Maximum LTV in basis points
     */
    function maxLtv() external view returns (uint256);

    /**
     * @notice Checks if the position is safe (below max LTV)
     * @return True if position is safe
     */
    function isPositionSafe() external view returns (bool);

    /**
     * @notice Returns the total debt in borrowed asset
     * @return Total debt amount
     */
    function totalDebt() external view returns (uint256);

    /**
     * @notice Returns the total collateral in collateral asset
     * @return Total collateral amount
     */
    function totalCollateral() external view returns (uint256);

    /**
     * @notice Returns the value in the yield vault
     * @return Yield vault balance in borrowed asset
     */
    function yieldVaultBalance() external view returns (uint256);

    /**
     * @notice Returns the collateral asset
     * @return The collateral asset
     */
    function collateralAsset() external view returns (IERC20WithDecimals);

    /**
     * @notice Returns the borrowed asset
     * @return The borrowed asset
     */
    function borrowedAsset() external view returns (IERC20WithDecimals);

    /**
     * @notice Returns the yield vault address
     * @return Address of the yield vault
     */
    function yieldVault() external view returns (address);

    /**
     * @notice Checks if a router is whitelisted for swaps
     * @param router Address of the router to check
     * @return True if router is whitelisted
     */
    function whitelistedRouters(address router) external view returns (bool);

    /**
     * @notice Returns the current slippage tolerance
     * @return Slippage in basis points
     */
    function slippage() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            STATE CHANGING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Performs upkeep operations on the carry trade position
     * @param upkeepData Encoded data specifying the upkeep action and parameters
     * @dev Can be used for rebalancing, compounding, or emergency exit
     */
    function upkeep(bytes calldata upkeepData) external;

    /**
     * @notice Emergency exit from the position
     * @param swapData Optional swap data to convert remaining borrowed asset to collateral
     * @dev This should unwind the entire position and return all possible funds
     */
    function emergencyExit(bytes calldata swapData) external;

    /**
     * @notice Compounds profits back into the position
     * @dev Borrows more against existing collateral if LTV allows
     */
    function compound() external;

    /**
     * @notice Whitelists or removes a router for swaps
     * @param router Address of the router
     * @param whitelist True to whitelist, false to remove
     */
    function whitelistRouter(address router, bool whitelist) external;

    /**
     * @notice Sets the slippage tolerance for swaps
     * @param _slippage The slippage in basis points (e.g., 500 = 5%)
     */
    function setSlippage(uint256 _slippage) external;
}
