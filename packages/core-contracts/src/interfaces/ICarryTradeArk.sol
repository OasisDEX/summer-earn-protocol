// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "./IArk.sol";
import {ArkParams} from "../types/ArkTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20WithDecimals is IERC20 {
    function decimals() external view returns (uint8);
}

/**
 * @title ICarryTradeArk
 * @notice Interface for Arks that implement carry trade strategies
 * @dev Extends IArk with carry trade specific functionality
 */
interface ICarryTradeArk is IArk {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    
    error InvalidMaxLtv(uint256 maxLtv);
    error PositionUnsafe(uint256 currentLtv, uint256 maxLtv);
    error InvalidSwapData();
    error SwapFailed();
    error PartialWithdrawalsNotAllowed();
    error InsufficientProfit();
    error RouterNotWhitelisted(address router);
    error SlippageTooHigh();
    error CollateralAndBorrowedAssetCannotBeTheSame();
    error InvalidAsset();
    error CollateralAssetDoesNotMatchBaseAsset();
    error ReceivedLessThanExpected();
    error InvalidBorrowAmountEncoding();
    error InvalidRepayAmount();
    error InvalidRouterForClosePosition();
    error InvalidSwapCalldataForClosePosition();
    
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    
    event PositionRebalanced(uint256 repayAmount, uint256 newLtv);
    event EmergencyExit(uint256 collateralRecovered, uint256 loss);
    event PositionCompounded(uint256 additionalBorrowed, uint256 newLtv);
    event RouterWhitelisted(address router, bool whitelisted);
    event Swapped(address sellToken, address router, uint256 amountIn, bytes swapCalldata);
    event SlippageSet(uint256 slippage);
    
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/
    
    enum UpkeepAction {
        REBALANCE,
        COMPOUND,
        EMERGENCY_EXIT
    }
    
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    struct CarryTradeParams {
        address _lendingPool;
        address _collateralAsset;
        address _borrowedAsset;
        address _yieldVault;
        uint256 _maxLtv;
        uint256 _slippage;
        ArkParams baseParams;
    }
    
    struct UpkeepData {
        UpkeepAction action;
        bytes actionData;
    }
    
    struct SwapData {
        address router;
        bytes swapCalldata;
        uint256 minAmountOut;
    }
    
    struct DisembarkData {
        bool closePosition;
        uint256 repayAmount;
        SwapData swapData;  // Use the structured SwapData type
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