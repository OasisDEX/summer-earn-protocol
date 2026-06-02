// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IArkSwapProvider} from "./IArkSwapProvider.sol";

/**
 * @title IArkWithWithdrawalRequest
 * @notice Interface for the Ark contract, which manages funds and interacts with Rafts
 * @notice Used for protocols that require a withdrawal request
 * @dev Inherits the curator-whitelisted router-swap surface (`withdrawUsingSwap`, `setSlippage`,
 *      `whitelistRouter`, `SwapData`, and the related errors/events) from `IArkSwapProvider`,
 *      which itself inherits `IArk`.
 */
interface IArkWithWithdrawalRequest is IArkSwapProvider {
    /// @notice Error thrown when a withdrawal has already been requested
    error WithdrawalAlreadyRequested();

    /// @notice Error thrown when there is no withdrawal request
    error NoWithdrawalToClaim();

    /// @notice Error thrown when a withdrawal has failed
    error WithdrawalFailed();

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
     * @notice Emitted when a previously requested withdrawal is cancelled.
     * @param shares The amount of shares that were returned as a result of the cancellation.
     */
    event WithdrawalCancelled(uint256 shares);
}
