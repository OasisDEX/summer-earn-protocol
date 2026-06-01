// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArk} from "./IArk.sol";

/**
 * @title IArkWithWithdrawalRequest
 * @notice Interface for the Ark contract, which manages funds and interacts with Rafts
 * @notice Used for protocols that require a withdrawal request
 * @dev Inherits from IArk for the Ark contract
 */
interface IArkWithWithdrawalRequest is IArk {
    /// @notice Error thrown when a withdrawal has already been requested
    error WithdrawalAlreadyRequested();

    /// @notice Error thrown when there is no withdrawal request
    error NoWithdrawalToClaim();

    /// @notice Error thrown when a withdrawal has failed
    error WithdrawalFailed();

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
     * @notice Sweeps all underlying assets from the Ark and boards them to bufferArk
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     * @return sweptTokens The addresses of the tokens swept
     * @return sweptAmounts The amounts of the tokens swept
     */
    function sweep()
        external
        returns (address[] memory sweptTokens, uint256[] memory sweptAmounts);

    /**
     * @notice Requests a withdrawal of underlying assets from the Ark.
     * @dev This function is only callable by the keeper.
     * @dev This function is non-reentrant.
     * @param amount The amount of underlying asset to request a withdrawal for.
     */
    function requestWithdrawal(uint256 amount) external;

    /**
     * @notice Claims a previously requested withdrawal of underlying assets from the Ark.
     * @dev This function is only callable by the keeper.
     * @dev This function is non-reentrant.
     */
    function claimWithdrawal() external;

    /**
     * @notice Returns the current withdrawal request id.
     * @return requestId The current withdrawal request id.
     */
    function withdrawalRequestId() external view returns (uint256 requestId);

    /**
     * @notice Returns the assets in the withdrawal queue.
     * @return assets The amount of underlying assets currently pending withdrawal.
     */
    function assetsInWithdrawalQueue() external view returns (uint256 assets);

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
     * @notice Returns whether a withdrawal claim is required for this Ark.
     * @dev It's a keeper helper method to check if a claim is required.
     * @return required Whether a withdrawal claim is required.
     */
    function isWithdrawalClaimRequired() external view returns (bool required);

    /**
     * @notice Emitted when a withdrawal is requested.
     * @param amount The amount of underlying asset requested for withdrawal.
     * @param withdrawalId The protocol-specific withdrawal id (0 for protocols without an id).
     */
    event WithdrawalRequested(uint256 amount, uint256 withdrawalId);

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

    /**
     * @notice Emitted when a previously requested withdrawal is cancelled.
     * @param shares The amount of shares that were returned as a result of the cancellation.
     */
    event WithdrawalCancelled(uint256 shares);
}
