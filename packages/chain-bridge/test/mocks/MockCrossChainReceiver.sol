// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ICrossChainMessageReceiver} from "../../src/interfaces/ICrossChainMessageReceiver.sol";
import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {ICrossChainStateReadReceiver} from "../../src/interfaces/ICrossChainStateReadReceiver.sol";

/**
 * @title MockCrossChainReceiver
 * @notice Mock contract that implements the ICrossChainReceiver interface for testing
 */
contract MockCrossChainReceiver is
    ICrossChainMessageReceiver,
    ICrossChainAssetReceiver,
    ICrossChainStateReadReceiver
{
    bytes public lastReceivedData;
    address public lastSender;
    uint16 public lastSourceChainId;
    bool public receiveSuccess = true;

    function setReceiveSuccess(bool success) external {
        receiveSuccess = success;
    }

    function receiveStateRead(
        bytes calldata data,
        address sender,
        uint16 sourceChainId,
        bytes32
    ) external override {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = data;
        lastSender = sender;
        lastSourceChainId = sourceChainId;
    }

    function receiveMessage(
        uint16 sourceChainId,
        bytes calldata message
    ) external override {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = message;
        lastSourceChainId = sourceChainId;
    }

    function receiveMessageWithAssets(
        address,
        uint256,
        bytes calldata message
    ) external {
        if (!receiveSuccess) revert("Receiver rejected call");

        lastReceivedData = message;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        external
        pure
        override(
            ICrossChainMessageReceiver,
            ICrossChainAssetReceiver,
            ICrossChainStateReadReceiver
        )
        returns (bool)
    {
        return interfaceId == type(ICrossChainMessageReceiver).interfaceId;
    }
}
