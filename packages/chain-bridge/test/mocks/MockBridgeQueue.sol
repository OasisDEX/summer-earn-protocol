// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IBridgeQueue} from "../../src/interfaces/IBridgeQueue.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract MockBridgeQueue is IBridgeQueue {
    // Storage for last call data for test assertions
    uint16 public lastDestinationChainId;
    address public lastAsset;
    uint256 public lastAmount;
    address public lastRecipient;
    BridgeTypes.BridgeOptions public lastOptions;
    bytes public lastMessage;

    function queueTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external override returns (bytes32) {
        lastDestinationChainId = destinationChainId;
        lastAsset = asset;
        lastAmount = amount;
        lastRecipient = recipient;
        lastOptions = options;
        return keccak256("transfer");
    }

    function queueSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external override returns (bytes32) {
        lastDestinationChainId = destinationChainId;
        lastRecipient = recipient;
        lastMessage = message;
        lastOptions = options;
        return keccak256("message");
    }

    // Implement stubs for other interface functions if needed for compilation
    // (You can leave them empty or revert)
    function bridgeRouter() external pure returns (address) {
        return address(0);
    }
    function isQueueManager(address) external pure override returns (bool) {
        return false;
    }
    function queuedTransfers(
        bytes32
    )
        external
        pure
        override
        returns (
            uint16,
            address,
            uint256,
            address,
            BridgeTypes.BridgeOptions memory,
            address,
            bytes32
        )
    {
        revert("not implemented");
    }
    function queuedReadStates(
        bytes32
    )
        external
        pure
        override
        returns (
            uint16,
            address,
            bytes4,
            bytes memory,
            BridgeTypes.BridgeOptions memory,
            address,
            bytes32
        )
    {
        revert("not implemented");
    }
    function queuedMessages(
        bytes32
    )
        external
        pure
        override
        returns (
            uint16,
            address,
            bytes memory,
            BridgeTypes.BridgeOptions memory,
            address,
            bytes32
        )
    {
        revert("not implemented");
    }
    function queueIdToOperationType(
        bytes32
    ) external pure override returns (BridgeTypes.OperationType) {
        revert("not implemented");
    }
    function queueIdToStatus(
        bytes32
    ) external pure override returns (BridgeTypes.OperationStatus) {
        revert("not implemented");
    }
    function operationIdToQueueId(
        bytes32
    ) external pure override returns (bytes32) {
        revert("not implemented");
    }
    function pendingQueueIds()
        external
        pure
        override
        returns (bytes32[] memory)
    {
        revert("not implemented");
    }
    function getPendingQueueCount() external pure override returns (uint256) {
        return 0;
    }
    function getPendingQueueIdAtIndex(
        uint256
    ) external pure override returns (bytes32) {
        revert("not implemented");
    }
    function getOperationStatus(
        bytes32
    ) external pure override returns (BridgeTypes.OperationStatus) {
        revert("not implemented");
    }
    function setBridgeRouter(address) external pure override {
        revert("not implemented");
    }
    function addQueueManager(address) external pure override {
        revert("not implemented");
    }
    function removeQueueManager(address) external pure override {
        revert("not implemented");
    }
    function dequeueOperation(bytes32) external pure override {
        revert("not implemented");
    }
    function recoverFunds(address, address, uint256) external pure override {
        revert("not implemented");
    }
}
