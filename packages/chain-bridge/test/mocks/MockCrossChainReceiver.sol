// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainReceiver} from "../../src/interfaces/ICrossChainReceiver.sol";

/**
 * @title MockCrossChainReceiver
 * @notice Mock contract that implements the ICrossChainReceiver interface for testing
 */
contract MockCrossChainReceiver is ICrossChainReceiver {
    bytes public lastReceivedData;
    address public lastSender;
    uint16 public lastSourceChainId;
    bytes32 public lastMessageId;
    bool public receiveSuccess = true;

    function setReceiveSuccess(bool success) external {
        receiveSuccess = success;
    }

    function receiveStateRead(
        bytes calldata data,
        address sender,
        uint16 sourceChainId,
        bytes32 messageId
    ) external override {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = data;
        lastSender = sender;
        lastSourceChainId = sourceChainId;
        lastMessageId = messageId;
    }

    function receiveMessage(
        bytes calldata data,
        address sender,
        uint16 sourceChainId,
        bytes32 messageId
    ) external override {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = data;
        lastSender = sender;
        lastSourceChainId = sourceChainId;
        lastMessageId = messageId;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return interfaceId == type(ICrossChainReceiver).interfaceId;
    }
}
