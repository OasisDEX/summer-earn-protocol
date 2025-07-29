// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
/**
 * @title MockCrossChainReceiver
 * @notice Mock contract that implements the ICrossChainReceiver interface for testing
 */
contract MockCrossChainReceiver is ICrossChainReceiver {
    bytes public lastReceivedData;
    address public lastSender;
    uint16 public lastSourceChainId;
    bool public receiveSuccess = true;

    function setReceiveSuccess(bool success) external {
        receiveSuccess = success;
    }

    function receiveOperation(
        BridgeTypes.OperationType operationType,
        bytes calldata encodedParams
    ) external {
        if (operationType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            BridgeTypes.DeliveredTransferParams memory params = abi.decode(
                encodedParams,
                (BridgeTypes.DeliveredTransferParams)
            );
            _processReceipt(
                params.message,
                msg.sender,
                params.operationId,
                params.sourceChainId
            );
        } else if (operationType == BridgeTypes.OperationType.MESSAGE) {
            BridgeTypes.DeliveredMessageParams memory params = abi.decode(
                encodedParams,
                (BridgeTypes.DeliveredMessageParams)
            );
            _processReceipt(
                params.message,
                msg.sender,
                params.operationId,
                params.sourceChainId
            );
        } else if (operationType == BridgeTypes.OperationType.READ_STATE) {
            BridgeTypes.DeliveredReadResponse memory params = abi.decode(
                encodedParams,
                (BridgeTypes.DeliveredReadResponse)
            );
            _processReceipt(
                params.readResponseData,
                msg.sender,
                params.operationId,
                params.sourceChainId
            );
        } else {
            revert InvalidOperationType();
        }
    }

    function _processReceipt(
        bytes memory data,
        address sender,
        bytes32,
        uint16 sourceChainId
    ) internal {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = data;
        lastSender = sender;
        lastSourceChainId = sourceChainId;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(ICrossChainReceiver) returns (bool) {
        return interfaceId == type(ICrossChainReceiver).interfaceId;
    }

    function testSkipper() public {}
}
