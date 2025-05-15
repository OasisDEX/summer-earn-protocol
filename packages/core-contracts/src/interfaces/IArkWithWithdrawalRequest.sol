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
     * @notice Requests a withdrawal of all underlying assets from the Ark
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     */
    function requestWithdrawal(uint256 amount) external;

    /**
     * @notice Claims a withdrawal of all underlying assets from the Ark
     * @dev This function is only callable by the keeper
     * @dev This function is non-reentrant
     */
    function claimWithdrawal() external;

    /**
     * @notice Returns the current withdrawal request id
     * @return The current withdrawal request id
     */
    function withdrawalRequestId() external view returns (uint256);

    /**
     * @notice Returns the assets in the withdrawal queue
     * @return The assets in the withdrawal queue
     */
    function assetsInWithdrawalQueue() external view returns (uint256);

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
     * @notice Returns whether a withdrawal claim is required for this Ark
     * @dev It's a keeper helper method to check if a claim is required
     * @return Whether a withdrawal claim is required
     */
    function isWithdrawalClaimRequired() external view returns (bool);

    event WithdrawalRequested(uint256 amount, uint256 withdrawalId);
    event RouterWhitelisted(address router, bool isWhitelisted);
    event SlippageSet(uint256 slippage);
    event Swapped(
        address token,
        address router,
        uint256 amount,
        bytes swapCalldata
    );
}
