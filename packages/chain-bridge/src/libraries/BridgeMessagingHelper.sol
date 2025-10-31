// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "./BridgeTypes.sol";
import {BridgeCodec} from "./BridgeCodec.sol";

/**
 * @title BridgeMessagingHelper
 * @notice Library providing encoding and decoding utilities for bridge messaging
 * @dev This library centralizes the encoding/decoding logic used across bridge adapters
 *      to reduce code duplication and improve maintainability.
 */
library BridgeMessagingHelper {
    /**
     * @notice Decode relayed message parameters from bytes
     * @param _message Encoded message parameters
     * @return Decoded RelayedMessageParams struct
     */
    function decodeRelayedMessageParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedMessageParams memory) {
        return abi.decode(_message, (BridgeTypes.RelayedMessageParams));
    }

    /**
     * @notice Decode relayed transfer parameters from bytes
     * @param _message Encoded transfer parameters
     * @return Decoded RelayedTransferParams struct
     */
    function decodeRelayedTransferParams(
        bytes memory _message
    ) internal pure returns (BridgeTypes.RelayedTransferParams memory) {
        return abi.decode(_message, (BridgeTypes.RelayedTransferParams));
    }

    /**
     * @notice Encode relayed message parameters to bytes
     * @param _params RelayedMessageParams struct to encode
     * @return Encoded message parameters
     */
    function encodeRelayedMessageParams(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return abi.encode(_params);
    }

    /**
     * @notice Encode relayed transfer parameters to bytes
     * @param _params RelayedTransferParams struct to encode
     * @return Encoded transfer parameters
     */
    function encodeRelayedTransferParams(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return abi.encode(_params);
    }

    /**
     * @notice Encode relayed message parameters with operation type prefix
     * @param _params RelayedMessageParams struct to encode
     * @return Encoded message parameters with operation type
     */
    function encodeRelayedMessageParamsWithType(
        BridgeTypes.RelayedMessageParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeCodec.encodePayload(
                BridgeTypes.OperationType.MESSAGE,
                encodeRelayedMessageParams(_params)
            );
    }

    /**
     * @notice Encode relayed transfer parameters with operation type prefix
     * @param _params RelayedTransferParams struct to encode
     * @return Encoded transfer parameters with operation type
     */
    function encodeRelayedTransferParamsWithType(
        BridgeTypes.RelayedTransferParams memory _params
    ) internal pure returns (bytes memory) {
        return
            BridgeCodec.encodePayload(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                encodeRelayedTransferParams(_params)
            );
    }

    /**
     * @notice Decode a payload to extract OperationType and data
     * @param payload The encoded payload with OperationType prefix
     * @return operationType The extracted operation type
     * @return data The remaining payload data after removing the prefix
     */
    function decodePayload(
        bytes calldata payload
    )
        internal
        pure
        returns (BridgeTypes.OperationType operationType, bytes memory data)
    {
        return BridgeCodec.decodePayload(payload);
    }

    /**
     * @notice Creates RelayedMessageParams from ExecuteSendMessageParams
     * @param params ExecuteSendMessageParams from the bridge operation
     * @param operationId The operation ID for this transaction
     * @return RelayedMessageParams struct ready for encoding
     */
    function createRelayedMessageParams(
        BridgeTypes.ExecuteSendMessageParams calldata params,
        bytes32 operationId
    ) internal view returns (BridgeTypes.RelayedMessageParams memory) {
        return
            BridgeTypes.RelayedMessageParams({
                recipient: params.target,
                message: params.message,
                operationId: operationId,
                originator: params.originator,
                sourceChainId: uint16(block.chainid)
            });
    }

    /**
     * @notice Creates RelayedTransferParams from ExecuteTransferParams
     * @param params ExecuteTransferParams from the bridge operation
     * @param operationId The operation ID for this transaction
     * @return RelayedTransferParams struct ready for encoding
     */
    function createRelayedTransferParams(
        BridgeTypes.ExecuteTransferParams memory params,
        bytes32 operationId
    ) internal view returns (BridgeTypes.RelayedTransferParams memory) {
        return
            BridgeTypes.RelayedTransferParams({
                recipient: params.target,
                asset: params.asset,
                amount: params.amount,
                sourceChainId: uint16(block.chainid),
                operationId: operationId,
                originator: params.originator,
                message: params.message
            });
    }
}
