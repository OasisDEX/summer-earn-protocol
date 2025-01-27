// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IAdmiralsQuartersErrors
 * @dev This file contains custom error definitions for the AdmiralsQuarters contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IAdmiralsQuartersErrors {
    /**
     * @notice Thrown when a swap operation fails.
     */
    error SwapFailed();

    /**
     * @notice Thrown when there's a mismatch between expected and actual assets in an operation.
     */
    error AssetMismatch();

    /**
     * @notice Thrown when the output amount from an operation is less than the expected minimum.
     */
    error InsufficientOutputAmount();

    /**
     * @notice Thrown when an invalid FleetCommander address is provided or used.
     */
    error InvalidFleetCommander();

    /**
     * @notice Thrown when an invalid token address is provided or used.
     */
    error InvalidToken();

    /**
     * @notice Thrown when an unsupported swap function is called or referenced.
     */
    error UnsupportedSwapFunction();

    /**
     * @notice Thrown when there's a mismatch between expected and actual swap amounts.
     */
    error SwapAmountMismatch();

    /**
     * @notice Thrown when a reentrancy attempt is detected.
     */
    error ReentrancyGuard();

    /**
     * @notice Thrown when an operation is attempted with a zero amount where a non-zero amount is required.
     */
    error ZeroAmount();

    /**
     * @notice Thrown when an invalid router address is provided or used.
     */
    error InvalidRouterAddress();

    /**
     * @notice Thrown when the provided token does not match the expected token.
     */
    error TokenMismatch();

    /**
     * @notice Thrown when an invalid WETH address is provided or used.
     */
    error InvalidNativeTokenAddress();

    /**
     * @notice Thrown when the provided native amount does not match the expected native amount.
     */
    error InvalidNativeAmount();

    /**
     * @notice Thrown when native token is not allowed.
     */
    error NativeTokenNotAllowed();

    /**
     * @notice Thrown when the provided rewards redeemer is invalid.
     */
    error InvalidRewardsRedeemer();

    /**
     * @notice Thrown when the provided rewards manager is invalid.
     */
    error InvalidRewardsManager();
}
