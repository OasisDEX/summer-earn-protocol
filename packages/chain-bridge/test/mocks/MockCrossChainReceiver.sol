// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICrossChainAssetReceiver} from "../../src/interfaces/ICrossChainAssetReceiver.sol";
import {ICrossChainMessageReceiver} from "../../src/interfaces/ICrossChainMessageReceiver.sol";
import {ICrossChainStateReadReceiver} from "../../src/interfaces/ICrossChainStateReadReceiver.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
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
        bytes calldata resultData,
        bytes32 requestId,
        uint16 sourceChainId
    ) external {
        _processReceipt(resultData, msg.sender, requestId, sourceChainId);
    }

    function receiveMessage(
        BridgeTypes.DeliveredMessageParams calldata params
    ) external {
        _processReceipt(
            params.message,
            msg.sender,
            bytes32(0),
            params.sourceChainId
        );
    }

    function receiveMessageWithAssets(
        address,
        uint256,
        bytes calldata message,
        uint16 sourceChainId
    ) external {
        _processReceipt(message, msg.sender, bytes32(0), sourceChainId);
    }

    function _processReceipt(
        bytes calldata data,
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
        return
            interfaceId == type(ICrossChainMessageReceiver).interfaceId ||
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(ICrossChainStateReadReceiver).interfaceId;
    }

    function testSkipper() public {}
}
