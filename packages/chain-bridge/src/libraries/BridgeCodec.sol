// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "./BridgeTypes.sol";

/**
 * @title BridgeCodec
 * @notice Library for encoding and decoding bridge operation payloads with OperationType prefixes
 * @dev Centralizes the logic for adding/removing uint16 OperationType prefixes to payloads
 */
library BridgeCodec {
    /// @notice Error thrown when payload is too short to contain operation type
    error InvalidPayloadLength();

    /// @notice Error thrown when operation type is invalid
    error InvalidOperationType();

    /**
     * @notice Encodes a payload with an OperationType prefix
     * @param operationType The operation type to prefix the payload with
     * @param data The data to encode
     * @return The encoded payload with OperationType prefix (uint16 + data)
     */
    function encodePayload(
        BridgeTypes.OperationType operationType,
        bytes memory data
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(uint16(operationType), data);
    }

    /**
     * @notice Decodes a payload to extract OperationType and data
     * @param raw The raw payload with OperationType prefix
     * @return operationType The extracted operation type
     * @return data The remaining payload data after removing the prefix
     */
    function decodePayload(
        bytes calldata raw
    )
        internal
        pure
        returns (BridgeTypes.OperationType operationType, bytes memory data)
    {
        if (raw.length < 2) {
            revert InvalidPayloadLength();
        }

        // Extract the first 2 bytes as uint16, then cast to OperationType
        uint16 opTypeRaw = uint16(bytes2(raw));

        // Validate that the operation type is within valid range
        if (opTypeRaw > uint16(type(BridgeTypes.OperationType).max)) {
            revert InvalidOperationType();
        }

        operationType = BridgeTypes.OperationType(opTypeRaw);

        // Use slice notation to get the remaining data
        data = raw[2:];
    }
}
