// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "./IArk.sol";

/**
 * @title IArkWithSwap
 * @notice Interface for Arks that can exit positions through a curator-whitelisted DEX-aggregator
 *         router swap (`withdrawUsingSwap`), with a curator-configured slippage bound.
 * @dev Split out of `IArkWithWithdrawalRequest` so synchronous Arks (e.g. swap-based RWA Arks) can
 *      use the router-swap machinery without inheriting the async-withdrawal surface.
 *      `IArkWithWithdrawalRequest` inherits this interface, so existing consumers are unaffected.
 */
interface IArkWithSwap is IArk {
    /// @notice Error thrown when a router is not whitelisted
    error RouterNotWhitelisted();

    /// @notice Error thrown when the slippage is too high
    error SlippageTooHigh();

    /// @notice Error thrown when the received amount is less than expected
    error ReceivedLessThanExpected();

    /// @notice Struct for the swap data
    struct SwapData {
        /// @notice The router address
        address router;
        /// @notice The swap data
        bytes swapCalldata;
    }

    /**
     * @notice Withdraws assets from the Ark using a swap
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     * @param amount The amount of assets to withdraw
     * @param data The data to pass to the swap (router and swap calldata)
     */
    function withdrawUsingSwap(uint256 amount, bytes calldata data) external;

    /**
     * @notice Sets the slippage for the swap
     * @notice the base is 10000 so 500 is 5%
     * @dev This function is only callable by the curator
     * @param slippage The slippage to set
     */
    function setSlippage(uint256 slippage) external;

    /**
     * @notice Whitelists a router
     * @dev This function is only callable by the curator
     * @param router The router to whitelist
     * @param isWhitelisted The boolean to set the whitelist to
     */
    function whitelistRouter(address router, bool isWhitelisted) external;

    /**
     * @notice Emitted when a router's whitelist status is updated.
     * @param router The router address whose status changed.
     * @param isWhitelisted The new whitelist status.
     */
    event RouterWhitelisted(address router, bool isWhitelisted);

    /**
     * @notice Emitted when `setSlippage` updates the swap slippage tolerance.
     * @param slippage The new slippage value, in basis points of `SLIPPAGE_BASE`.
     */
    event SlippageSet(uint256 slippage);

    /**
     * @notice Emitted by `_swap` after a successful router call.
     * @param token The sold token address.
     * @param router The router address that executed the swap.
     * @param amount The amount of `token` sold.
     * @param swapCalldata The calldata forwarded to the router.
     */
    event Swapped(
        address token,
        address router,
        uint256 amount,
        bytes swapCalldata
    );
}
