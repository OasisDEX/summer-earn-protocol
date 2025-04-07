// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";

/**
 * @title MockBridgeRouter
 * @notice Mock implementation of IBridgeRouter for testing purposes
 * @dev Implements only the minimum functionality needed for testing CrossChainArkProxy
 */
contract MockBridgeRouter {
    // Mapping to store operation statuses
    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;

    // Variables to control mock behavior
    bytes32 public nextTransferId;
    bytes32 public nextMessageId;
    bytes32 public nextReadId;
    bool public mockPaused;
    bool public shouldRevert;
    uint256 public mockFee;
    address public mockSelectedAdapter;

    // Track calls for verification
    struct TransferCall {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address recipient;
    }

    struct MessageCall {
        uint16 destinationChainId;
        address recipient;
        bytes message;
    }

    TransferCall[] public transferCalls;
    MessageCall[] public messageCalls;

    // Events for tracking mock calls
    event MockTransferAssets(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );
    event MockSendMessage(
        bytes32 operationId,
        uint16 destinationChainId,
        address recipient,
        bytes message
    );

    /**
     * @notice Configure the mock behavior
     * @param _nextTransferId ID to return for next transfer
     * @param _nextMessageId ID to return for next message
     * @param _nextReadId ID to return for next read
     * @param _mockPaused Whether router is paused
     * @param _shouldRevert Whether operations should revert
     * @param _mockFee Mock fee to return in quotes
     * @param _mockSelectedAdapter Mock adapter to return in quotes
     */
    function configureMock(
        bytes32 _nextTransferId,
        bytes32 _nextMessageId,
        bytes32 _nextReadId,
        bool _mockPaused,
        bool _shouldRevert,
        uint256 _mockFee,
        address _mockSelectedAdapter
    ) external {
        nextTransferId = _nextTransferId;
        nextMessageId = _nextMessageId;
        nextReadId = _nextReadId;
        mockPaused = _mockPaused;
        shouldRevert = _shouldRevert;
        mockFee = _mockFee;
        mockSelectedAdapter = _mockSelectedAdapter;
    }

    /**
     * @notice Set the next transfer ID to return
     * @param _transferId ID to return
     */
    function setNextTransferId(bytes32 _transferId) external {
        nextTransferId = _transferId;
    }

    /**
     * @notice Set the next message ID to return
     * @param _messageId ID to return
     */
    function setNextMessageId(bytes32 _messageId) external {
        nextMessageId = _messageId;
    }

    /**
     * @notice Set the next read ID to return
     * @param _readId ID to return
     */
    function setNextReadId(bytes32 _readId) external {
        nextReadId = _readId;
    }

    /**
     * @notice Set mock paused state
     * @param _paused Whether router is paused
     */
    function setMockPaused(bool _paused) external {
        mockPaused = _paused;
    }

    /**
     * @notice Set whether operations should revert
     * @param _shouldRevert Whether operations should revert
     */
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    /**
     * @notice Clear recorded calls
     */
    function clearCalls() external {
        delete transferCalls;
        delete messageCalls;
    }

    /**
     * @notice Get number of transfer calls
     * @return Number of transfer calls
     */
    function getTransferCallCount() external view returns (uint256) {
        return transferCalls.length;
    }

    /**
     * @notice Get number of message calls
     * @return Number of message calls
     */
    function getMessageCallCount() external view returns (uint256) {
        return messageCalls.length;
    }

    /**
     * @notice Set the status of an operation
     * @param operationId ID of the operation
     * @param status Status to set
     */
    function setOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external {
        operationStatuses[operationId] = status;
    }

    // IBridgeRouter implementation (without override)

    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert("Paused");
        if (shouldRevert) revert("TransferFailed");

        // Record the call
        transferCalls.push(
            TransferCall({
                destinationChainId: destinationChainId,
                asset: asset,
                amount: amount,
                recipient: recipient
            })
        );

        emit MockTransferAssets(
            nextTransferId,
            destinationChainId,
            asset,
            amount,
            recipient
        );
        return nextTransferId;
    }

    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert("Paused");
        if (shouldRevert) revert("ReceiverRejectedCall");

        // Record the call
        messageCalls.push(
            MessageCall({
                destinationChainId: destinationChainId,
                recipient: recipient,
                message: message
            })
        );

        emit MockSendMessage(
            nextMessageId,
            destinationChainId,
            recipient,
            message
        );
        return nextMessageId;
    }

    function readState(
        uint16,
        address,
        bytes4,
        bytes calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable returns (bytes32) {
        if (mockPaused) revert("Paused");
        if (shouldRevert) revert("ReceiverRejectedCall");

        return nextReadId;
    }

    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
    }

    function quote(
        uint16,
        address,
        uint256,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.OperationType
    ) external view returns (uint256, uint256, address) {
        return (mockFee, 0, mockSelectedAdapter);
    }

    function paused() external view returns (bool) {
        return mockPaused;
    }

    function getBestAdapter(
        uint16,
        address,
        uint256,
        BridgeTypes.OperationType
    ) external view returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapter(
        uint16,
        address,
        uint256
    ) external view returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapterForTransfer(
        uint16,
        address,
        uint256
    ) external view returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapterForMessaging(
        uint16
    ) external view returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapterForStateRead(
        uint16
    ) external view returns (address) {
        return mockSelectedAdapter;
    }

    function isValidAdapter(address) external view returns (bool) {
        return true;
    }

    function getRouterBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getAdapterList() external view returns (address[] memory) {
        address[] memory adapters = new address[](1);
        adapters[0] = mockSelectedAdapter;
        return adapters;
    }

    function getChainToRouterAddress(uint16) external view returns (address) {
        return address(this);
    }

    function acceptsAsset(address, uint16) external view returns (bool) {
        return true;
    }

    // Implement remaining IBridgeRouter functions without override

    function registerAdapter(address) external {}
    function removeAdapter(address) external {}
    function pause() external {}
    function unpause() external {}
    function setFeeMultiplier(uint256) external {}
    function setConfirmationGasLimit(uint64) external {}
    function setChainRouterAddress(uint16, address) external {}
    function removeRouterFunds(address, uint256) external {}
    function addRouterFunds() external payable {}
    function notifyMessageReceived(
        bytes32,
        address,
        uint256,
        address,
        uint16
    ) external {}
    function notifyTransferReceived(bytes32, address, uint16) external {}
    function receiveConfirmation(bytes32, address, uint16) external {}
    function receiveConfirmation(
        bytes32,
        BridgeTypes.OperationStatus
    ) external {}
    function recoverOperationStatus(
        bytes32,
        BridgeTypes.OperationStatus
    ) external {}
    function deliverReadResponse(bytes32, bytes calldata) external {}
    function updateOperationStatus(
        bytes32,
        BridgeTypes.OperationStatus
    ) external {}
    function updateReceiveStatus(
        bytes32,
        address,
        BridgeTypes.OperationStatus
    ) external {}
    function getAdapters() external view returns (address[] memory) {
        return new address[](0);
    }
}
