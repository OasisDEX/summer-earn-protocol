// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title BridgeQueue
 * @notice Queues cross-chain operations (transfers, reads, messages) for later execution by keepers.
 * @dev Interacts with a BridgeRouter to get quotes and trigger executions.
 */
contract BridgeQueue is ProtocolAccessManaged, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the associated BridgeRouter contract
    IBridgeRouter public bridgeRouter;

    /// @notice Address allowed to queue operations (e.g., CrossChainArk or specific manager role)
    address public queueManager; // Using a single address for simplicity, could be role-based

    /// @notice Nonce to ensure unique queue IDs
    uint256 private queueNonce;

    /// @notice Struct to store queued transfer details
    struct QueuedTransfer {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address recipient;
        BridgeTypes.BridgeOptions options;
        address originator;
        uint256 feePaid; // Total fee collected from originator
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @notice Struct to store queued state read details
    struct QueuedReadState {
        uint16 dstChainId;
        address dstContract;
        bytes4 selector;
        bytes readParams;
        BridgeTypes.BridgeOptions options;
        address originator;
        uint256 feePaid; // Total fee collected from originator
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @notice Struct to store queued message details
    struct QueuedMessage {
        uint16 destinationChainId;
        address recipient;
        bytes message;
        BridgeTypes.BridgeOptions options;
        address originator;
        uint256 feePaid; // Total fee collected from originator
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @notice Mapping from queue IDs to queued transfer data
    mapping(bytes32 queueId => QueuedTransfer) public queuedTransfers;
    /// @notice Mapping from queue IDs to queued read state data
    mapping(bytes32 queueId => QueuedReadState) public queuedReadStates;
    /// @notice Mapping from queue IDs to queued message data
    mapping(bytes32 queueId => QueuedMessage) public queuedMessages;

    /// @notice Mapping from queue IDs to the type of operation queued
    mapping(bytes32 queueId => BridgeTypes.OperationType)
        public queueIdToOperationType;

    /// @notice Mapping from queue IDs to their status
    mapping(bytes32 queueId => BridgeTypes.OperationStatus)
        public queueIdToStatus;

    /// @notice Mapping from adapter-generated operation IDs back to our queue ID
    mapping(bytes32 operationId => bytes32 queueId) public operationIdToQueueId;

    /// @notice Array of pending queue IDs for keepers to process
    bytes32[] public pendingQueueIds;
    /// @notice Mapping to efficiently find the index of a queue ID in pendingQueueIds (index + 1)
    mapping(bytes32 queueId => uint256) private pendingQueueIdIndex;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BridgeRouterUpdated(address indexed newBridgeRouter);
    event QueueManagerUpdated(address indexed newQueueManager);
    event OperationQueued(
        bytes32 indexed queueId,
        BridgeTypes.OperationType indexed operationType,
        address indexed originator,
        uint16 destinationChainId,
        uint256 feePaid
    );
    event OperationExecuted(
        bytes32 indexed queueId,
        bytes32 indexed operationId,
        address indexed executor
    );
    event OperationDequeued(bytes32 indexed queueId, address indexed remover);
    event QueueExecutionFailed(
        bytes32 indexed queueId,
        address indexed executor,
        bytes reason
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidBridgeRouter();
    error InvalidQueueManager();
    error CallerNotQueueManager();
    error InvalidParams();
    error InsufficientFee();
    error TransferFailed();
    error QueueIdNotFound();
    error OperationNotQueued();
    error AlreadyProcessed();
    error RouterExecutionFailed();
    error FeeCalculationError();
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyQueueManager() {
        if (msg.sender != queueManager) revert CallerNotQueueManager();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _queueManager
    ) ProtocolAccessManaged(_accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_queueManager == address(0)) revert InvalidQueueManager();
        bridgeRouter = IBridgeRouter(_bridgeRouter);
        queueManager = _queueManager;
        emit BridgeRouterUpdated(_bridgeRouter);
        emit QueueManagerUpdated(_queueManager);
    }

    /*//////////////////////////////////////////////////////////////
                       QUEUEING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _queueOperation(
        BridgeTypes.OperationType opType,
        uint16 destinationChainId,
        address asset, // Only relevant for TRANSFER_ASSET
        uint256 amount, // Only relevant for TRANSFER_ASSET
        BridgeTypes.BridgeOptions memory options // memory to allow modification
    ) internal view returns (uint256 totalNativeFee, uint256 totalTokenFee) {
        // Ensure router is set
        if (address(bridgeRouter) == address(0)) revert InvalidBridgeRouter();

        // Get quote from the router
        (totalNativeFee, totalTokenFee, ) = bridgeRouter.quote(
            destinationChainId,
            asset,
            amount,
            options,
            opType
        );
    }

    function queueTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyQueueManager returns (bytes32 queueId) {
        if (asset == address(0) || amount == 0 || recipient == address(0))
            revert InvalidParams();

        (uint256 totalNativeFee, uint256 totalTokenFee) = _queueOperation(
            BridgeTypes.OperationType.TRANSFER_ASSET,
            destinationChainId,
            asset,
            amount,
            options
        );

        if (msg.value < totalNativeFee) revert InsufficientFee();
        // Handle token fees if necessary in the future, currently assuming native fee only for simplicity

        // Generate unique ID
        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), queueNonce++)
        );

        // Store details
        queuedTransfers[queueId] = QueuedTransfer({
            destinationChainId: destinationChainId,
            asset: asset,
            amount: amount,
            recipient: recipient,
            options: options,
            originator: msg.sender, // The actual entity requesting via the queue manager
            feePaid: msg.value, // Store the total fee paid
            operationId: bytes32(0) // Not executed yet
        });
        queueIdToOperationType[queueId] = BridgeTypes
            .OperationType
            .TRANSFER_ASSET;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        // Add to pending list
        pendingQueueIds.push(queueId);
        pendingQueueIdIndex[queueId] = pendingQueueIds.length; // Store index + 1

        // Transfer asset from originator (queue manager) to this queue contract
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Return excess fee if any
        if (msg.value > totalNativeFee) {
            (bool success, ) = msg.sender.call{
                value: msg.value - totalNativeFee
            }("");
            if (!success) revert TransferFailed();
        }

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.TRANSFER_ASSET,
            msg.sender,
            destinationChainId,
            msg.value
        );
        return queueId;
    }

    function queueReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyQueueManager returns (bytes32 queueId) {
        if (dstContract == address(0)) revert InvalidParams();

        (uint256 totalNativeFee, uint256 totalTokenFee) = _queueOperation(
            BridgeTypes.OperationType.READ_STATE,
            dstChainId,
            address(0), // No asset
            0, // No amount
            options
        );

        if (msg.value < totalNativeFee) revert InsufficientFee();

        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), queueNonce++)
        );

        queuedReadStates[queueId] = QueuedReadState({
            dstChainId: dstChainId,
            dstContract: dstContract,
            selector: selector,
            readParams: readParams,
            options: options,
            originator: msg.sender,
            feePaid: msg.value,
            operationId: bytes32(0)
        });
        queueIdToOperationType[queueId] = BridgeTypes.OperationType.READ_STATE;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        pendingQueueIds.push(queueId);
        pendingQueueIdIndex[queueId] = pendingQueueIds.length;

        if (msg.value > totalNativeFee) {
            (bool success, ) = msg.sender.call{
                value: msg.value - totalNativeFee
            }("");
            if (!success) revert TransferFailed();
        }

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.READ_STATE,
            msg.sender,
            dstChainId,
            msg.value
        );
        return queueId;
    }

    function queueSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyQueueManager returns (bytes32 queueId) {
        if (recipient == address(0)) revert InvalidParams();

        (uint256 totalNativeFee, uint256 totalTokenFee) = _queueOperation(
            BridgeTypes.OperationType.MESSAGE,
            destinationChainId,
            address(0), // No asset
            0, // No amount
            options
        );

        if (msg.value < totalNativeFee) revert InsufficientFee();

        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), queueNonce++)
        );

        queuedMessages[queueId] = QueuedMessage({
            destinationChainId: destinationChainId,
            recipient: recipient,
            message: message,
            options: options,
            originator: msg.sender,
            feePaid: msg.value,
            operationId: bytes32(0)
        });
        queueIdToOperationType[queueId] = BridgeTypes.OperationType.MESSAGE;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        pendingQueueIds.push(queueId);
        pendingQueueIdIndex[queueId] = pendingQueueIds.length;

        if (msg.value > totalNativeFee) {
            (bool success, ) = msg.sender.call{
                value: msg.value - totalNativeFee
            }("");
            if (!success) revert TransferFailed();
        }

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.MESSAGE,
            msg.sender,
            destinationChainId,
            msg.value
        );
        return queueId;
    }

    /*//////////////////////////////////////////////////////////////
                       QUEUE EXECUTION FUNCTION
    //////////////////////////////////////////////////////////////*/

    function executeQueuedOperation(
        bytes32 queueId
    ) external nonReentrant returns (bytes32 operationId) {
        // Check existence and status
        uint256 index = pendingQueueIdIndex[queueId];
        if (index == 0) revert QueueIdNotFound(); // Not in pending list
        if (queueIdToStatus[queueId] != BridgeTypes.OperationStatus.QUEUED)
            revert OperationNotQueued();

        BridgeTypes.OperationType opType = queueIdToOperationType[queueId];
        uint256 feePaid = 0;
        uint256 baseFee = 0;
        uint256 routerFeeMultiplier = bridgeRouter.feeMultiplier();
        if (routerFeeMultiplier == 0) revert FeeCalculationError(); // Avoid division by zero

        address executor = msg.sender; // Keeper executing the call

        // Prepare for router call based on type
        try
            bridgeRouter.supportsInterface(type(IBridgeRouter).interfaceId)
        returns (bool routerSupported) {
            if (!routerSupported) revert InvalidBridgeRouter(); // Basic check

            if (opType == BridgeTypes.OperationType.TRANSFER_ASSET) {
                QueuedTransfer storage transferData = queuedTransfers[queueId];
                feePaid = transferData.feePaid;
                baseFee = (feePaid * 100) / routerFeeMultiplier; // Calculate base fee

                // Approve router to spend the asset held by this queue contract
                IERC20(transferData.asset).approve(
                    address(bridgeRouter),
                    transferData.amount
                );

                // Call router's execute method
                operationId = bridgeRouter.executeTransferAssets{
                    value: baseFee
                }(
                    transferData.destinationChainId,
                    transferData.asset,
                    transferData.amount,
                    transferData.recipient,
                    transferData.originator, // Pass original requestor
                    transferData.options
                );

                // Reset approval
                IERC20(transferData.asset).approve(address(bridgeRouter), 0);
            } else if (opType == BridgeTypes.OperationType.READ_STATE) {
                QueuedReadState storage readData = queuedReadStates[queueId];
                feePaid = readData.feePaid;
                baseFee = (feePaid * 100) / routerFeeMultiplier;

                operationId = bridgeRouter.executeReadState{value: baseFee}(
                    readData.dstChainId,
                    readData.dstContract,
                    readData.selector,
                    readData.readParams,
                    readData.originator,
                    readData.options
                );
            } else if (opType == BridgeTypes.OperationType.MESSAGE) {
                QueuedMessage storage messageData = queuedMessages[queueId];
                feePaid = messageData.feePaid;
                baseFee = (feePaid * 100) / routerFeeMultiplier;

                operationId = bridgeRouter.executeSendMessage{value: baseFee}(
                    messageData.destinationChainId,
                    messageData.recipient,
                    messageData.message,
                    messageData.originator,
                    messageData.options
                );
            } else {
                revert("Unknown Operation Type"); // Should not happen
            }
        } catch (bytes memory reason) {
            emit QueueExecutionFailed(queueId, executor, reason);
            // Keep the operation in the queue, maybe retry later or requires admin action
            // Do NOT remove from pendingQueueIds here
            return bytes32(0); // Indicate failure
        }

        // --- Success Path ---

        // Link operationId back to queueId
        operationIdToQueueId[operationId] = queueId;

        // Store operationId in the specific queue struct
        if (opType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            queuedTransfers[queueId].operationId = operationId;
        } else if (opType == BridgeTypes.OperationType.READ_STATE) {
            queuedReadStates[queueId].operationId = operationId;
        } else if (opType == BridgeTypes.OperationType.MESSAGE) {
            queuedMessages[queueId].operationId = operationId;
        }

        // Update status (now PENDING in the router)
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.PENDING; // Mirror router's initial state

        // Remove from pending list
        _removePendingId(queueId, index - 1);

        emit OperationExecuted(queueId, operationId, executor);

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Removes a queue ID from the pending list by swapping with the last element.
     * @param queueId The ID to remove.
     * @param index The index of the ID in the `pendingQueueIds` array.
     */
    function _removePendingId(bytes32 queueId, uint256 index) internal {
        uint256 lastIndex = pendingQueueIds.length - 1;
        if (index != lastIndex) {
            // Swap with the last element
            bytes32 lastId = pendingQueueIds[lastIndex];
            pendingQueueIds[index] = lastId;
            pendingQueueIdIndex[lastId] = index + 1; // Update index of the moved element
        }
        // Remove the last element
        pendingQueueIds.pop();
        // Mark the removed ID's index as 0
        pendingQueueIdIndex[queueId] = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPendingQueueCount() external view returns (uint256) {
        return pendingQueueIds.length;
    }

    function getPendingQueueIdAtIndex(
        uint256 index
    ) external view returns (bytes32) {
        return pendingQueueIds[index];
    }

    function getOperationStatus(
        bytes32 queueId
    ) external view returns (BridgeTypes.OperationStatus) {
        // If executed, query the router for the most up-to-date status
        bytes32 operationId = bytes32(0);
        if (
            queueIdToOperationType[queueId] ==
            BridgeTypes.OperationType.TRANSFER_ASSET
        ) {
            operationId = queuedTransfers[queueId].operationId;
        } else if (
            queueIdToOperationType[queueId] ==
            BridgeTypes.OperationType.READ_STATE
        ) {
            operationId = queuedReadStates[queueId].operationId;
        } else if (
            queueIdToOperationType[queueId] == BridgeTypes.OperationType.MESSAGE
        ) {
            operationId = queuedMessages[queueId].operationId;
        }

        if (operationId != bytes32(0)) {
            try bridgeRouter.getOperationStatus(operationId) returns (
                BridgeTypes.OperationStatus status
            ) {
                return status;
            } catch {
                // If router reverts (e.g., ID not found yet), return our last known status
                return queueIdToStatus[queueId];
            }
        }
        // Not executed yet, return our internal status
        return queueIdToStatus[queueId];
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setBridgeRouter(address _newBridgeRouter) external onlyGovernor {
        if (_newBridgeRouter == address(0)) revert InvalidBridgeRouter();
        bridgeRouter = IBridgeRouter(_newBridgeRouter);
        emit BridgeRouterUpdated(_newBridgeRouter);
    }

    function setQueueManager(address _newQueueManager) external onlyGovernor {
        if (_newQueueManager == address(0)) revert InvalidQueueManager();
        queueManager = _newQueueManager;
        emit QueueManagerUpdated(_newQueueManager);
    }

    /**
     * @notice Allows admin to remove an operation from the pending queue (e.g., if stuck or invalid).
     * @param queueId The ID of the operation to dequeue.
     */
    function dequeueOperation(
        bytes32 queueId
    ) external onlyGovernor nonReentrant {
        uint256 index = pendingQueueIdIndex[queueId];
        if (index == 0) revert QueueIdNotFound(); // Not pending
        if (queueIdToStatus[queueId] != BridgeTypes.OperationStatus.QUEUED)
            revert OperationNotQueued();

        // Refund logic (optional, complex depending on asset/fee)
        // For simplicity, we might require a separate refund mechanism or just burn fees/assets
        // Example: Refund native fee if possible
        BridgeTypes.OperationType opType = queueIdToOperationType[queueId];
        uint256 feePaid = 0;
        address originator = address(0);

        if (opType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            feePaid = queuedTransfers[queueId].feePaid;
            originator = queuedTransfers[queueId].originator;
            // Potentially transfer asset back
            IERC20(queuedTransfers[queueId].asset).safeTransfer(
                originator,
                queuedTransfers[queueId].amount
            );
        } else if (opType == BridgeTypes.OperationType.READ_STATE) {
            feePaid = queuedReadStates[queueId].feePaid;
            originator = queuedReadStates[queueId].originator;
        } else if (opType == BridgeTypes.OperationType.MESSAGE) {
            feePaid = queuedMessages[queueId].feePaid;
            originator = queuedMessages[queueId].originator;
        }

        if (originator != address(0) && feePaid > 0) {
            // Attempt to refund native fee - might fail if contract has insufficient balance
            payable(originator).transfer(feePaid);
        }

        // Remove from pending list
        _removePendingId(queueId, index - 1);

        // Update status to FAILED (or a new DEQUEUED status if preferred)
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.FAILED; // Using FAILED for simplicity

        // Clean up storage (optional, saves gas on future reads but costs gas now)
        // delete queuedTransfers[queueId];
        // delete queuedReadStates[queueId];
        // delete queuedMessages[queueId];
        // delete queueIdToOperationType[queueId];
        // delete operationIdToQueueId[queued...[queueId].operationId]; // If operationId was somehow set

        emit OperationDequeued(queueId, msg.sender);
    }

    // Allow governor to withdraw surplus native tokens (fees kept by router/queue)
    function withdrawSurplusNative(
        address payable recipient,
        uint256 amount
    ) external onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();
        if (address(this).balance < amount) revert InsufficientBalance();
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    // Allow governor to withdraw surplus ERC20 tokens (if any accumulate unexpectedly)
    function withdrawSurplusERC20(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();
        token.safeTransfer(recipient, amount);
    }

    // Add receive() and fallback() if needed to accept plain ETH transfers
    receive() external payable {}
    fallback() external payable {}
}
