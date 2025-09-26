// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainReceiverBase} from "../../src/base/CrossChainReceiverBase.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

/**
 * @title MockCrossChainReceiver
 * @notice Mock contract that implements the ICrossChainReceiver interface for testing
 * @dev Supports all operation types for comprehensive testing
 */
contract MockCrossChainReceiver is CrossChainReceiverBase {
    bytes public lastReceivedData;
    address public lastSender;
    uint16 public lastSourceChainId;
    bytes32 public lastOperationId;
    BridgeTypes.OperationType public lastOperationType;
    bool public receiveSuccess = true;
    bool public shouldRevertAuth;

    function setReceiveSuccess(bool success) external {
        receiveSuccess = success;
    }

    function setShouldRevertAuth(bool _shouldRevertAuth) external {
        shouldRevertAuth = _shouldRevertAuth;
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN RECEIVER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mock authorization check - can be configured to revert for testing
     */
    function _requireAuthorizedCaller() internal view override {
        if (shouldRevertAuth) {
            revert Unauthorized();
        }
        // In mock, we don't enforce real authorization for testing flexibility
    }

    /**
     * @notice Returns all supported operation types for comprehensive testing
     */
    function _getSupportedOperationTypes()
        internal
        pure
        override
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        supportedTypes = new BridgeTypes.OperationType[](2);
        supportedTypes[0] = BridgeTypes.OperationType.MESSAGE;
        supportedTypes[1] = BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /**
     * @notice Handles MESSAGE operations
     */
    function _handleMessage(
        BridgeTypes.RelayedMessageParams memory params
    ) internal override {
        _processReceipt(
            params.message,
            msg.sender,
            params.operationId,
            params.sourceChainId,
            BridgeTypes.OperationType.MESSAGE
        );
    }

    /**
     * @notice Handles TRANSFER_ASSET operations
     */
    function _handleTransferAsset(
        BridgeTypes.RelayedTransferParams memory params
    ) internal override {
        _processReceipt(
            params.message,
            msg.sender,
            params.operationId,
            params.sourceChainId,
            BridgeTypes.OperationType.TRANSFER_ASSET
        );
    }

    // READ_STATE handler removed

    function _processReceipt(
        bytes memory data,
        address sender,
        bytes32 operationId,
        uint16 sourceChainId,
        BridgeTypes.OperationType operationType
    ) internal {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = data;
        lastSender = sender;
        lastSourceChainId = sourceChainId;
        lastOperationId = operationId;
        lastOperationType = operationType;
    }

    function testSkipper() public {}
}
