// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title MockBridgeRouter
 * @notice Mock implementation of IBridgeRouter for testing purposes
 * @dev Implements only the minimum functionality needed for testing CrossChainArkProxy
 */
contract MockBridgeRouter is IBridgeRouter {
    using EnumerableSet for EnumerableSet.AddressSet;

    // Set of registered adapters
    EnumerableSet.AddressSet private adapters;

    // Mapping to store operation statuses
    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;

    // Mapping of operation IDs to the adapter that processed them
    mapping(bytes32 => address) public operationToAdapter;

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

    // IBridgeRouter implementation

    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata
    ) external payable override returns (bytes32) {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert TransferFailed();

        // Record the call
        transferCalls.push(
            TransferCall({
                destinationChainId: destinationChainId,
                asset: asset,
                amount: amount,
                recipient: recipient
            })
        );

        // Associate the operation with the adapter if specified
        if (mockSelectedAdapter != address(0)) {
            operationToAdapter[nextTransferId] = mockSelectedAdapter;
        }

        emit TransferInitiated(
            nextTransferId,
            destinationChainId,
            asset,
            amount,
            recipient,
            mockSelectedAdapter
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
    ) external payable override returns (bytes32) {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert ReceiverRejectedCall();

        // Record the call
        messageCalls.push(
            MessageCall({
                destinationChainId: destinationChainId,
                recipient: recipient,
                message: message
            })
        );

        // Associate the operation with the adapter if specified
        if (mockSelectedAdapter != address(0)) {
            operationToAdapter[nextMessageId] = mockSelectedAdapter;
        }

        emit MessageInitiated(
            nextMessageId,
            destinationChainId,
            recipient,
            mockSelectedAdapter
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
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata
    ) external payable override returns (bytes32) {
        if (mockPaused) revert Paused();
        if (shouldRevert) revert ReceiverRejectedCall();

        // Associate the operation with the adapter if specified
        if (mockSelectedAdapter != address(0)) {
            operationToAdapter[nextReadId] = mockSelectedAdapter;
        }

        emit ReadRequestInitiated(
            nextReadId,
            dstChainId,
            dstContract,
            selector,
            readParams,
            mockSelectedAdapter
        );

        return nextReadId;
    }

    function getOperationStatus(
        bytes32 operationId
    ) external view override returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
    }

    function quote(
        uint16,
        address,
        uint256,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.OperationType
    ) external view override returns (uint256, uint256, address) {
        return (mockFee, 0, mockSelectedAdapter);
    }

    function getBestAdapter(
        uint16,
        address,
        uint256,
        BridgeTypes.OperationType
    ) external view override returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapter(
        uint16,
        address,
        uint256
    ) external view override returns (address) {
        return mockSelectedAdapter;
    }

    function getBestAdapterForStateRead(
        uint16
    ) external view override returns (address) {
        return mockSelectedAdapter;
    }

    function isValidAdapter(
        address adapter
    ) external view override returns (bool) {
        return adapters.contains(adapter);
    }

    function getRouterBalance() external view override returns (uint256) {
        return address(this).balance;
    }

    function getAdapters() external view override returns (address[] memory) {
        return adapters.values();
    }

    // Mock adapter management functions

    function registerAdapter(address adapter) external override {
        if (adapters.contains(adapter)) revert AdapterAlreadyRegistered();

        adapters.add(adapter);
        emit AdapterRegistered(adapter);
    }

    function removeAdapter(address adapter) external override {
        if (!adapters.contains(adapter)) revert UnknownAdapter();

        adapters.remove(adapter);
        emit AdapterRemoved(adapter);
    }

    // Simplified notification implementation for testing

    function notifyMessageReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external override {
        // Set the operation status to DELIVERED
        operationStatuses[operationId] = BridgeTypes.OperationStatus.DELIVERED;

        emit OperationStatusUpdated(
            operationId,
            BridgeTypes.OperationStatus.DELIVERED
        );

        emit MessageDelivered(operationId, recipient, true);

        // If this is a transfer (asset is not zero and amount > 0), emit the transfer event
        if (asset != address(0) && amount > 0) {
            emit TransferReceived(
                operationId,
                asset,
                amount,
                recipient,
                sourceChainId
            );
        }

        // Forward the message to the recipient for testing purposes
        if (messageCalls.length > 0) {
            (bool success, ) = recipient.call(
                abi.encodeWithSelector(
                    0x6d79eede, // receiveMessage selector
                    messageCalls[messageCalls.length - 1].message, // Use the last message sent
                    messageCalls[messageCalls.length - 1].recipient, // Use the last recipient
                    sourceChainId,
                    operationId
                )
            );

            if (!success) {
                // If forwarding fails, update status to FAILED
                operationStatuses[operationId] = BridgeTypes
                    .OperationStatus
                    .FAILED;
                emit OperationStatusUpdated(
                    operationId,
                    BridgeTypes.OperationStatus.FAILED
                );
                emit MessageDelivered(operationId, recipient, false);
            }
        }
    }

    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external override {
        if (!adapters.contains(msg.sender)) revert UnknownAdapter();
        if (operationToAdapter[operationId] != msg.sender)
            revert Unauthorized();

        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    // Minimal implementations of required interface methods

    function pause() external override {
        mockPaused = true;
    }

    function unpause() external override {
        mockPaused = false;
    }

    function receiveConfirmation(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external override {
        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external override {
        operationStatuses[operationId] = status;
        emit OperationStatusUpdated(operationId, status);
    }

    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) external override {
        operationStatuses[requestId] = status;
        emit OperationStatusUpdated(requestId, status);

        if (status != BridgeTypes.OperationStatus.DELIVERED) {
            emit MessageDelivered(requestId, recipient, false);
        }
    }

    // Unused interface methods with empty implementations
    function setFeeMultiplier(uint256) external override {}
    function setConfirmationGasLimit(uint64) external override {}
    function setChainRouterAddress(uint16, address) external override {}
    function removeRouterFunds(address, uint256) external override {}
    function addRouterFunds() external payable override {}
    function deliverReadResponse(bytes32, bytes calldata) external override {}
}
