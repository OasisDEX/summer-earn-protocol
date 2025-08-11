// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBridgeAdapter
 * @notice Core interface for bridge adapters with shared functionality
 * @dev Provides unified methods for bridge adapters. Adapters should also inherit from
 * @dev IAssetAdapter and/or IMessageAdapter based on their capabilities
 */
interface IBridgeAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a relay or messaging operation fails
    event RelayFailed(bytes32 indexed transferId, bytes reason);

    /// @notice Emitted when bridge router is updated
    event BridgeRouterUpdated(address oldRouter, address newRouter);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when insufficient msg.value is provided for the specified msgValue
    error InsufficientMsgValue(uint128 required, uint256 provided);

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when the operation is not supported by the adapter
    error UnsupportedOperation();

    /// @notice Thrown when the operation is not supported by the adapter
    error OperationNotSupported();

    /// @notice Thrown when insufficient fee is provided for an operation
    error InsufficientFee(uint256 required, uint256 provided);

    /// @notice Thrown when a read channel is not configured for a chain
    error ReadChannelNotConfigured();

    /// @notice Thrown when trying to set bridge router to zero address
    error InvalidBridgeRouter();

    /// @notice Thrown when an asset is not supported by the adapter
    error UnsupportedAsset();

    /// @notice Thrown when the contract has insufficient balance
    error InsufficientBalance();

    /// @notice Thrown when an unsupported message type is received
    error UnsupportedMessageType();

    /// @notice Error for slippage exceeding tolerance
    error SlippageExceedsTolerance(
        uint256 expectedAmount,
        uint256 receivedAmount,
        uint256 toleranceBps
    );

    /// @notice Error for untrusted Stargate pool contract
    error Untrusted(string what, address from, address additionalInfo);

    /**
     * @notice Estimate fees for a cross-chain operation (unified interface)
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer (address(0) for non-asset operations)
     * @param amount Amount of the asset to transfer (0 for non-asset operations)
     * @param options Bridge options including adapter selection and parameters
     * @param operationType Type of operation (0=MESSAGE, 1=READ_STATE, 2=TRANSFER_ASSET)
     * @return nativeFee Fee in the chain's native token
     * @return tokenFee Fee in the transferred token (if applicable)
     * @dev This method delegates to estimateTransferFee or estimateMessageFee based on operationType
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    ) external view returns (uint256 nativeFee, uint256 tokenFee);

    /**
     * @notice Check if an adapter supports a specific operation type
     * @param operationType Type of operation to check support for
     * @return Whether the adapter supports the operation type
     * @dev This method should check both asset and message capabilities based on operationType
     */
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external view returns (bool);
}
