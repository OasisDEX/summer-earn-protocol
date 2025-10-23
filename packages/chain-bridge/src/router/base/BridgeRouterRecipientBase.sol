// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {CrossChainConfigManaged} from "../../contracts/CrossChainConfigManaged.sol";
import {BridgeRouterValidationBase} from "./BridgeRouterValidationBase.sol";
import {IBridgeRouter} from "../../interfaces/IBridgeRouter.sol";

/**
 * @title BridgeRouterRecipientBase
 * @notice Abstract base contract providing recipient override and validation for BridgeRouter operations
 * @dev Contains recipient override logic and peer relationship validation
 */
abstract contract BridgeRouterRecipientBase is
    CrossChainConfigManaged,
    BridgeRouterValidationBase
{
    /*//////////////////////////////////////////////////////////////
                        RETRY RECIPIENT OVERRIDE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Apply recipient override (use original if newRecipient is zero)
            address finalRecipient = newRecipient != address(0)
                ? newRecipient
                : params.recipient;

            // Validate ark-fleet (peer) relationship for the final recipient
            _validatePeerRelationship(
                params.originator,
                finalRecipient,
                params.sourceChainId
            );

            // Update the payload with the final recipient
            params.recipient = finalRecipient;

            return abi.encode(params);
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                originalPayload,
                (BridgeTypes.RelayedMessageParams)
            );

            // Apply recipient override (use original if newRecipient is zero)
            address finalRecipient = newRecipient != address(0)
                ? newRecipient
                : params.recipient;

            // Validate ark-fleet (peer) relationship for the final recipient
            _validatePeerRelationship(
                params.originator,
                finalRecipient,
                params.sourceChainId
            );

            // Update the payload with the final recipient
            params.recipient = finalRecipient;

            return abi.encode(params);
        } else {
            // For unsupported operation types, return original payload
            return originalPayload;
        }
    }

    /*//////////////////////////////////////////////////////////////
                        PAYLOAD VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that an ark <> fleet (peer) relationship is valid in both directions
     * @param originator The originator address (sender-side peer)
     * @param recipient The recipient address (receiver-side peer)
     * @param sourceChainId The source chain ID
     */
    function _validatePeerRelationship(
        address originator,
        address recipient,
        uint16 sourceChainId
    ) internal view {
        bool isValidPair = CROSS_CHAIN_REGISTRY.isValidCrossChainPair(
            originator,
            recipient,
            sourceChainId,
            uint16(block.chainid),
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );

        if (!isValidPair) {
            revert IBridgeRouter.InvalidRecipient();
        }
    }
}
