// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {ICrossChainRegistry} from "../../interfaces/ICrossChainRegistry.sol";
import {ICrossChainReceiver} from "../../interfaces/ICrossChainReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CrossChainConfigManaged} from "../../contracts/CrossChainConfigManaged.sol";
import {BridgeRouterValidationBase} from "./BridgeRouterValidationBase.sol";
import {BridgeRouterRecipientBase} from "./BridgeRouterRecipientBase.sol";
import {IBridgeRouter} from "../../interfaces/IBridgeRouter.sol";

/**
 * @title BridgeRouterDeliveryBase
 * @notice Abstract base contract providing delivery processing for BridgeRouter operations
 * @dev Contains delivery routing and processing logic
 */
abstract contract BridgeRouterDeliveryBase is
    CrossChainConfigManaged,
    BridgeRouterValidationBase,
    BridgeRouterRecipientBase
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        DELIVERY PROCESSING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates that the operation type is supported
     * @param operationType The type of operation to validate
     */
    function _validateOperationType(
        BridgeTypes.OperationType operationType
    ) internal pure {
        if (operationType == BridgeTypes.OperationType.READ_STATE) {
            revert IBridgeRouter.UnsupportedOperationType();
        }
        if (
            operationType != BridgeTypes.OperationType.TRANSFER_ASSET &&
            operationType != BridgeTypes.OperationType.MESSAGE
        ) {
            revert IBridgeRouter.UnsupportedOperationType();
        }
    }

    /**
     * @dev Decodes operation metadata from payload
     * @param operationType The type of operation
     * @param operationPayload The encoded operation payload
     * @return operationId The extracted operation ID
     * @return sourceChainId The extracted source chain ID
     */
    function _decodeOperationMeta(
        BridgeTypes.OperationType operationType,
        bytes memory operationPayload
    ) internal pure returns (bytes32 operationId, uint16 sourceChainId) {
        DecodedOperationData memory data = _decodeCommonOperationData(
            operationType,
            operationPayload
        );
        return (data.operationId, data.sourceChainId);
    }

    /**
     * @notice Internal processing of a delivery wrapped in a self-call for atomicity.
     * @dev MUST only be invoked by this contract via `this._processDelivery(...)`.
     */
    function _processDelivery(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload,
        address adapter
    ) external {
        if (msg.sender != address(this)) revert IBridgeRouter.Unauthorized();

        // Validate operation type early
        _validateOperationType(operationType);

        // Decode common operation data
        DecodedOperationData memory data = _decodeCommonOperationData(
            operationType,
            operationPayload
        );

        // Perform common validations
        _assertPeerMappingExistsForChainFromAdapter(
            data.sourceChainId,
            adapter
        );
        _requireReceiverIsCrossChainReceiver(data.recipient);

        // Handle operation-specific logic
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory transferData = abi.decode(
                operationPayload,
                (BridgeTypes.RelayedTransferParams)
            );

            // Transfer the asset
            IERC20(transferData.asset).safeTransfer(
                transferData.recipient,
                transferData.amount
            );

            ICrossChainReceiver(transferData.recipient).receiveOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.MESSAGE,
                operationPayload
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Asserts that a peer mapping exists for the given chain and adapter
     * @param sourceChainId The source chain ID
     * @param adapter The adapter address
     */
    function _assertPeerMappingExistsForChainFromAdapter(
        uint16 sourceChainId,
        address adapter
    ) internal view virtual {
        address sourceContract = CROSS_CHAIN_REGISTRY.getSourceForTarget(
            sourceChainId,
            uint16(block.chainid),
            adapter,
            CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP()
        );

        if (sourceContract == address(0)) {
            revert ICrossChainRegistry.RelationshipDoesNotExist(
                address(0),
                CROSS_CHAIN_REGISTRY.PEER_RELATIONSHIP(),
                uint16(block.chainid)
            );
        }
    }
}
