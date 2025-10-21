// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IBaseBridgeAdapterErrors
 * @notice Interface containing all error definitions for BaseBridgeAdapter
 * @dev Following the IArkErrors pattern for consistent error definitions
 */
interface IBaseBridgeAdapterErrors {
    /// @notice Error thrown when destination chain peer is not trusted by governance
    error UntrustedDestinationChain(uint16 chainId);

    /// @notice Error thrown when source adapter is not trusted
    error UntrustedSourceAdapter(address srcAdapter, uint16 srcChain);

    /// @notice Error thrown when the amount is invalid
    error InvalidAmount();

    /// @notice Error thrown when the source chain ID is invalid
    error InvalidSourceChainId();

    /// @notice Error thrown when chain ID exceeds uint16 max value
    error ChainIdTooLarge(uint256 chainId);

    /// @notice Thrown when a call is made by an unauthorized address
    error Unauthorized();

    /// @notice Error thrown when the message is invalid
    error InvalidMessage();

    /// @notice Error thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Thrown when a native token transfer fails
    error TransferFailed();
}
