// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;
interface IAdmiralsQuartersErrors {
    /**
     * @title AdmiralsQuartersErrors
     * @dev This file contains custom error definitions for the AdmiralsQuarters contract.
     * @notice These custom errors provide more gas-efficient and informative error handling
     * compared to traditional require statements with string messages.
     */

    /**
     * @dev Thrown when a swap operation fails.
     */
    error SwapFailed();

    /**
     * @dev Thrown when there's a mismatch between expected and actual assets in an operation.
     */
    error AssetMismatch();

    /**
     * @dev Thrown when the output amount from an operation is less than the expected minimum.
     */
    error InsufficientOutputAmount();

    /**
     * @dev Thrown when an invalid FleetCommander address is provided or used.
     */
    error InvalidFleetCommander();

    /**
     * @dev Thrown when an invalid token address is provided or used.
     */
    error InvalidToken();

    /**
     * @dev Thrown when an unsupported swap function is called or referenced.
     */
    error UnsupportedSwapFunction();

    /**
     * @dev Thrown when there's a mismatch between expected and actual swap amounts.
     */
    error SwapAmountMismatch();

    /**
     * @dev Thrown when a reentrancy attempt is detected.
     */
    error ReentrancyGuard();

    /**
     * @dev Thrown when an operation is attempted with a zero amount where a non-zero amount is required.
     */
    error ZeroAmount();

    /**
     * @dev Thrown when an invalid router address is provided or used.
     */
    error InvalidRouterAddress();
}
