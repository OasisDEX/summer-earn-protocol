// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {BridgeRouterValidationBase} from "./BridgeRouterValidationBase.sol";

/**
 * @title BridgeRouterRecipientBase
 * @notice Abstract base contract providing recipient override and validation for BridgeRouter operations
 * @dev Contains recipient override logic and peer relationship validation
 */
abstract contract BridgeRouterRecipientBase is BridgeRouterValidationBase {
    /*//////////////////////////////////////////////////////////////
                        INTERNAL DATA STRUCTURES
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Common decoded operation data shared across operation types
     */
    struct DecodedOperationData {
        bytes32 operationId;
        uint16 sourceChainId;
        address recipient;
        address originator;
        address asset; // For TRANSFER_ASSET operations
        uint256 amount; // For TRANSFER_ASSET operations
        bytes message; // For both operation types
    }

    /*//////////////////////////////////////////////////////////////
                        RETRY RECIPIENT OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Decodes common operation data from payload
     * @param operationType The type of operation
     * @param operationPayload The encoded operation payload
     * @return data The decoded common operation data
     */
    function _decodeCommonOperationData(
        BridgeTypes.OperationType operationType,
        bytes memory operationPayload
    ) internal pure returns (DecodedOperationData memory data) {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );
            data.operationId = params.operationId;
            data.sourceChainId = params.sourceChainId;
            data.recipient = params.recipient;
            data.originator = params.originator;
            data.asset = params.asset;
            data.amount = params.amount;
            data.message = params.message;
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedMessageParams)
            );
            data.operationId = params.operationId;
            data.sourceChainId = params.sourceChainId;
            data.recipient = params.recipient;
            data.originator = params.originator;
            data.asset = address(0); // Not applicable for MESSAGE operations
            data.amount = 0; // Not applicable for MESSAGE operations
            data.message = params.message;
        }
    }

    /**
     * @notice Applies recipient override to the operation payload
     * @param operationType Type of operation being retried
     * @param originalPayload The original payload
     * @param newRecipient The new recipient address
     * @return modifiedPayload The payload with recipient override applied
     * @dev Applies recipient override and validates ark <> fleet (peer) relationship for the final recipient
     */
    function _applyRecipientOverride(
        BridgeTypes.OperationType operationType,
        bytes memory originalPayload,
        address newRecipient
    ) internal view returns (bytes memory modifiedPayload) {
        // Decode common operation data once
        DecodedOperationData memory data = _decodeCommonOperationData(
            operationType,
            originalPayload
        );

        address finalRecipient = newRecipient != address(0)
            ? newRecipient
            : data.recipient;

        if (finalRecipient == data.recipient) {
            _validatePeerRelationship(
                data.originator,
                finalRecipient,
                data.sourceChainId
            );
            return originalPayload;
        }

        // Validate ark-fleet (peer) relationship for the final recipient
        _validatePeerRelationship(
            data.originator,
            finalRecipient,
            data.sourceChainId
        );

        // Handle operation-specific payload updates with unified logic
        return
            _updatePayloadRecipient(
                operationType,
                originalPayload,
                finalRecipient
            );
    }

    /**
     * @dev Unified helper to update recipient in operation payload
     * @param operationType Type of operation
     * @param originalPayload The original payload
     * @param newRecipient The new recipient address
     * @return modifiedPayload The payload with updated recipient
     */
    function _updatePayloadRecipient(
        BridgeTypes.OperationType operationType,
        bytes memory originalPayload,
        address newRecipient
    ) internal pure returns (bytes memory modifiedPayload) {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedTransferParams)
            );
            params.recipient = newRecipient;
            return abi.encode(params);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedMessageParams)
            );
            params.recipient = newRecipient;
            return abi.encode(params);
        } else {
            // For unsupported operation types, return original payload
            return originalPayload;
        }
    }
}
