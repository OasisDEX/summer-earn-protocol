// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainReceiver} from "../interfaces/ICrossChainReceiver.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title CrossChainReceiverBase
 * @notice Base contract for implementing cross-chain operation receivers
 * @dev Provides unified receiveOperation method that decodes operation types and delegates to internal handlers
 */
abstract contract CrossChainReceiverBase is ICrossChainReceiver {
    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ICrossChainReceiver
     * @notice Receives and routes cross-chain operations to appropriate handlers
     * @param operationType The type of operation being delivered
     * @param encodedParams Encoded operation parameters
     */
    function receiveOperation(
        BridgeTypes.OperationType operationType,
        bytes calldata encodedParams
    ) external virtual override {
        // Access control check - must be implemented by derived contracts
        _requireAuthorizedCaller();

        if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.RelayedMessageParams memory params = abi.decode(
                encodedParams,
                (BridgeTypes.RelayedMessageParams)
            );
            _handleMessage(params);
        } else if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.RelayedTransferParams memory params = abi.decode(
                encodedParams,
                (BridgeTypes.RelayedTransferParams)
            );
            _handleTransferAsset(params);
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            BridgeTypes.RelayedReadResponse memory params = abi.decode(
                encodedParams,
                (BridgeTypes.RelayedReadResponse)
            );
            _handleReadStateResponse(params);
        } else {
            revert UnsupportedOperationType();
        }
    }

    /**
     * @inheritdoc ICrossChainReceiver
     * @notice Returns the operation types supported by this receiver
     * @return supportedTypes Array of supported operation types
     */
    function getSupportedOperationTypes()
        external
        view
        virtual
        override
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        return _getSupportedOperationTypes();
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure virtual override returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL VIRTUAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles MESSAGE operation type
     * @param // params // Decoded message parameters
     * @dev Override this function to handle message operations
     */
    function _handleMessage(
        BridgeTypes.RelayedMessageParams memory // params
    ) internal virtual {
        // Default implementation reverts for unsupported operation
        revert UnsupportedOperationType();
    }

    /**
     * @notice Handles TRANSFER_ASSET operation type
     * @param // params // Decoded transfer parameters
     * @dev Override this function to handle asset transfer operations
     */
    function _handleTransferAsset(
        BridgeTypes.RelayedTransferParams memory // params
    ) internal virtual {
        // Default implementation reverts for unsupported operation
        revert UnsupportedOperationType();
    }

    /**
     * @notice Handles READ_STATE response operation type
     * @param // params // Decoded read state response parameters
     * @dev Override this function to handle read state responses
     */
    function _handleReadStateResponse(
        BridgeTypes.RelayedReadResponse memory /*params*/
    ) internal virtual {
        // Default implementation reverts for unsupported operation
        revert UnsupportedOperationType();
    }

    /**
     * @notice Returns the operation types supported by this receiver
     * @return supportedTypes Array of supported operation types
     * @dev Override this function to specify which operations are supported
     */
    function _getSupportedOperationTypes()
        internal
        view
        virtual
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        // Default implementation returns empty array
        return new BridgeTypes.OperationType[](0);
    }

    /**
     * @notice Validates that the caller is authorized to call receiveOperation
     * @dev Must be implemented by derived contracts to enforce access control
     */
    function _requireAuthorizedCaller() internal view virtual;
}
