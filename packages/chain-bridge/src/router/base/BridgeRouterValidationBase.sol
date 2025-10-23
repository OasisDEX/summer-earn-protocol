// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../../interfaces/IBridgeAdapter.sol";
import {ICrossChainReceiver} from "../../interfaces/ICrossChainReceiver.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IBridgeRouter} from "../../interfaces/IBridgeRouter.sol";
import {CrossChainConfigManaged} from "../../contracts/CrossChainConfigManaged.sol";

/**
 * @title BridgeRouterValidationBase
 * @notice Abstract base contract providing validation utilities for BridgeRouter operations
 * @dev Contains all validation logic extracted from BridgeRouter
 */
abstract contract BridgeRouterValidationBase is CrossChainConfigManaged {
    /*//////////////////////////////////////////////////////////////
                        VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to validate transfer parameters
     * @param params Parameters to validate
     */
    function _validateTransferParams(
        BridgeTypes.ExecuteTransferParams calldata params
    ) internal pure {
        if (
            params.amount == 0 ||
            params.target == address(0) ||
            params.originator == address(0) ||
            params.asset == address(0) ||
            params.refundAddress == address(0) ||
            params.destinationChainId == 0
        ) revert IBridgeRouter.InvalidParams();
    }

    /**
     * @dev Internal function to validate send message parameters
     * @param params Parameters to validate
     */
    function _validateSendMessageParams(
        BridgeTypes.ExecuteSendMessageParams calldata params
    ) internal pure {
        if (
            params.target == address(0) ||
            params.originator == address(0) ||
            params.destinationChainId == 0 ||
            params.refundAddress == address(0) ||
            params.message.length == 0
        ) {
            revert IBridgeRouter.InvalidParams();
        }
    }

    /**
     * @dev Internal function to validate originator
     * @param originator The originator address
     */
    function _validateOriginator(address originator) internal view {
        if (originator != msg.sender) revert IBridgeRouter.InvalidOriginator();
    }

    /**
     * @dev Internal function to validate if an adapter supports a specific operation type
     * @param adapter The adapter address to validate
     * @param operationType The type of operation to check support for
     */
    function _validateAdapterSupportsOperation(
        address adapter,
        BridgeTypes.OperationType operationType
    ) internal view {
        if (adapter == address(0)) revert IBridgeRouter.NoSuitableAdapter();
        if (!IBridgeAdapter(adapter).supportsOperation(operationType)) {
            revert IBridgeRouter.UnsupportedAdapterOperation();
        }
    }

    /**
     * @dev Ensures `receiver` is a contract that supports `ICrossChainReceiver` via ERC165
     *      Reverts with `InvalidParams` otherwise.
     * @param receiver The address to validate
     */
    function _validateCrossChainReceiver(address receiver) internal view {
        if (receiver.code.length == 0) revert IBridgeRouter.InvalidParams();
        try
            IERC165(receiver).supportsInterface(
                type(ICrossChainReceiver).interfaceId
            )
        returns (bool isSupported) {
            if (!isSupported) revert IBridgeRouter.InvalidParams();
        } catch {
            revert IBridgeRouter.InvalidParams();
        }
    }

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
