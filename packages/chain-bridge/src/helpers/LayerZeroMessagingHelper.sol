// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";

/**
 * @title LayerZeroMessagingHelper
 *
 * @notice Helper library for LayerZero-specific messaging utilities
 *
 * @dev Provides utilities for creating message parameters, validating fees, and handling LayerZero-specific operations
 */
library LayerZeroMessagingHelper {
    /**
     * @notice Creates RelayedMessageParams from ExecuteSendMessageParams
     *
     * @param params ExecuteSendMessageParams from the bridge operation
     * @param operationId The operation ID for this transaction
     *
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
     * @notice Validates that sufficient msg.value was provided for the operation
     *
     * @param options Bridge options containing msgValue requirement
     * @param msgValue The actual msg.value sent with the transaction
     */
    function validateFeeRequirements(
        BridgeTypes.BridgeOptions calldata options,
        uint256 msgValue
    ) internal pure {
        // Sent fee must meet or exceed required msgValue
        if (options.msgValue > 0 && msgValue < options.msgValue) {
            revert IBridgeAdapter.InsufficientMsgValue(
                options.msgValue,
                msgValue
            );
        }
    }
}
