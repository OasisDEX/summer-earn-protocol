// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Bps} from "../helpers/Bps.sol";

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

    /// @notice Thrown when insufficient msg.value is provided for the specified msgValue
    error InsufficientMsgValue(uint128 required, uint256 provided);

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when the operation is not supported by the adapter
    error OperationNotSupported();

    /// @notice Thrown when insufficient fee is provided for an operation
    error InsufficientFee(uint256 required, uint256 provided);

    /// @notice Thrown when an asset is not supported by the adapter
    error UnsupportedAsset();

    /// @notice Thrown when an unsupported message type is received
    error UnsupportedMessageType();

    /// @notice Error for slippage exceeding tolerance
    error SlippageExceedsTolerance(
        uint256 expectedAmount,
        uint256 receivedAmount,
        Bps toleranceBps
    );

    /// @notice Error for untrusted external contracts or entities that fail validation
    /// @param what Description of what failed validation (e.g., "Stargate pool", "bridge contract")
    /// @param from Address of the untrusted contract or entity
    /// @param additionalInfo Additional context address (e.g., expected address, related contract)
    /// @dev Used for general validation failures not covered by more specific errors like UntrustedSourceAdapter
    error Untrusted(string what, address from, address additionalInfo);
}
