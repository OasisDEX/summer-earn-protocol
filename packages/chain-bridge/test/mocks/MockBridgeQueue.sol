// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IBridgeQueue} from "../../src/interfaces/IBridgeQueue.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockBridgeQueue is IBridgeQueue {
    // Storage for last call data for test assertions
    uint16 public lastDestinationChainId;
    address public lastAsset;
    uint256 public lastAmount;
    address public lastRecipient;
    bytes public lastMessage;

    /// @inheritdoc IBridgeQueue
    function queueTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        bytes calldata /* message */
    ) external returns (bytes32) {
        lastDestinationChainId = destinationChainId;
        lastAsset = asset;
        lastAmount = amount;
        lastRecipient = recipient;
        return keccak256("transfer");
    }

    /// @inheritdoc IBridgeQueue
    function queueSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message
    ) external returns (bytes32) {
        lastDestinationChainId = destinationChainId;
        lastRecipient = recipient;
        lastMessage = message;
        return keccak256("message");
    }

    /// @inheritdoc IBridgeQueue
    function queueReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4,
        bytes calldata readParams
    ) external returns (bytes32) {
        lastDestinationChainId = dstChainId;
        lastAsset = dstContract;
        lastMessage = readParams;
        return keccak256("read");
    }

    /// @inheritdoc IBridgeQueue
    function executeQueuedOperation(
        bytes32,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        return keccak256("executed");
    }

    // Implement stubs for other interface functions if needed for compilation
    function bridgeRouter() external pure returns (address) {
        return address(0);
    }

    function isQueueManager(address) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IBridgeQueue
    function queuedTransfers(
        bytes32
    )
        external
        pure
        returns (
            uint16,
            address,
            uint256,
            bytes memory,
            address,
            address,
            bytes32
        )
    {
        revert("not implemented");
    }

    /// @inheritdoc IBridgeQueue
    function queuedReadStates(
        bytes32
    )
        external
        pure
        returns (uint16, address, bytes4, bytes memory, address, bytes32)
    {
        revert("not implemented");
    }

    /// @inheritdoc IBridgeQueue
    function queuedMessages(
        bytes32
    ) external pure returns (uint16, address, bytes memory, address, bytes32) {
        revert("not implemented");
    }

    function queueIdToOperationType(
        bytes32
    ) external pure returns (BridgeTypes.OperationType) {
        revert("not implemented");
    }

    function queueIdToStatus(
        bytes32
    ) external pure returns (BridgeTypes.OperationStatus) {
        revert("not implemented");
    }

    function operationIdToQueueId(bytes32) external pure returns (bytes32) {
        revert("not implemented");
    }

    function pendingQueueIds() external pure returns (bytes32[] memory) {
        revert("not implemented");
    }

    function getPendingQueueCount() external pure returns (uint256) {
        return 0;
    }

    function getPendingQueueIdAtIndex(uint256) external pure returns (bytes32) {
        revert("not implemented");
    }

    function getOperationStatus(
        bytes32
    ) external pure returns (BridgeTypes.OperationStatus) {
        revert("not implemented");
    }

    function setBridgeRouter(address) external pure {
        revert("not implemented");
    }

    function addQueueManager(address) external pure {
        revert("not implemented");
    }

    function removeQueueManager(address) external pure {
        revert("not implemented");
    }

    function dequeueOperation(bytes32) external pure {
        revert("not implemented");
    }

    function recoverFunds(address, address, uint256) external pure {
        revert("not implemented");
    }
}
