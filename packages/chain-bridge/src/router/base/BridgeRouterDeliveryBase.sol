// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../libraries/BridgeTypes.sol";
import {ICrossChainRegistry} from "../../interfaces/ICrossChainRegistry.sol";
import {ICrossChainReceiver} from "../../interfaces/ICrossChainReceiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BridgeRouterValidationBase} from "./BridgeRouterValidationBase.sol";
import {BridgeRouterRecipientBase} from "./BridgeRouterRecipientBase.sol";
import {IBridgeRouter} from "../../interfaces/IBridgeRouter.sol";

/**
 * @title BridgeRouterDeliveryBase
 * @notice Abstract base contract providing delivery processing for BridgeRouter operations
 * @dev Contains delivery routing and processing logic
 */
abstract contract BridgeRouterDeliveryBase is
    BridgeRouterValidationBase,
    BridgeRouterRecipientBase
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to ensure function can only be called by this contract
     */
    modifier onlySelf() {
        if (msg.sender != address(this)) revert IBridgeRouter.Unauthorized();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        DELIVERY PROCESSING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Validates that the operation type is supported
     * @param operationType The type of operation to validate
     * @dev READ_STATE is reserved for future implementation
     */
    function _validateOperationType(
        BridgeTypes.OperationType operationType
    ) internal pure {
        if (
            operationType != BridgeTypes.OperationType.TRANSFER_ASSET &&
            operationType != BridgeTypes.OperationType.MESSAGE
        ) {
            revert IBridgeRouter.UnsupportedOperationType();
        }
    }

    /**
     * @notice Internal processing of a delivery wrapped in a self-call for atomicity.
     * @dev MUST only be invoked by this contract via `this.processDelivery(...)`.
     */
    function processDelivery(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload,
        address adapter
    ) external onlySelf {
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
        _validateCrossChainReceiver(data.recipient);

        // Handle operation-specific logic
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            // Transfer the asset using data from already decoded struct
            IERC20(data.asset).safeTransfer(data.recipient, data.amount);

            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.TRANSFER_ASSET,
                operationPayload
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            ICrossChainReceiver(data.recipient).receiveOperation(
                BridgeTypes.OperationType.MESSAGE,
                operationPayload
            );
        } else {
            // This should never happen due to _validateOperationType, but adding for safety
            revert IBridgeRouter.UnsupportedOperationType();
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
