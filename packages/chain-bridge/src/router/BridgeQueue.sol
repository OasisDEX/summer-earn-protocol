// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {DeploymentAccessManaged} from "@summerfi/access-contracts/contracts/DeploymentAccessManaged.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBridgeQueue} from "../interfaces/IBridgeQueue.sol";
import {ICrossChainArk} from "../interfaces/ICrossChainArk.sol";
import {IInflightAssetTracking} from "../interfaces/IInflightAssetTracking.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";

/**
 * @title BridgeQueue
 * @notice Queues cross-chain operations (transfers, reads, messages) for later execution by keepers.
 * @dev Interacts with a BridgeRouter to get quotes and trigger executions. Implements IBridgeQueue.
 */
contract BridgeQueue is IBridgeQueue, DeploymentAccessManaged, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Address of the associated BridgeRouter contract
    address public bridgeRouter;

    /// @inheritdoc IBridgeQueue
    mapping(address => bool) public isQueueManager;

    /// @notice Nonce to ensure unique queue IDs
    uint256 private _queueNonce;

    /// @notice Pseudo-address used to represent native currency (ETH)
    address public constant NATIVE_PSEUDO_ADDRESS =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @notice Struct to store queued transfer details
    struct QueuedTransfer {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address recipient;
        address originator; // Address that must pre-approve this contract for 'amount' of 'asset'
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @notice Struct to store queued state read details
    struct QueuedReadState {
        uint16 dstChainId;
        address dstContract;
        bytes4 selector;
        bytes readParams;
        address originator;
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @notice Struct to store queued message details
    struct QueuedMessage {
        uint16 destinationChainId;
        address recipient;
        bytes message;
        address originator;
        bytes32 operationId; // ID returned by adapter upon execution
    }

    /// @inheritdoc IBridgeQueue
    mapping(bytes32 queueId => QueuedTransfer) public queuedTransfers;
    /// @inheritdoc IBridgeQueue
    mapping(bytes32 queueId => QueuedReadState) public queuedReadStates;
    /// @inheritdoc IBridgeQueue
    mapping(bytes32 queueId => QueuedMessage) public queuedMessages;

    /// @inheritdoc IBridgeQueue
    mapping(bytes32 queueId => BridgeTypes.OperationType)
        public queueIdToOperationType;

    /// @inheritdoc IBridgeQueue
    mapping(bytes32 queueId => BridgeTypes.OperationStatus)
        public queueIdToStatus;

    /// @inheritdoc IBridgeQueue
    mapping(bytes32 operationId => bytes32 queueId) public operationIdToQueueId;

    /// @notice Array of pending queue IDs for keepers to process. Accessed via pendingQueueIds().
    bytes32[] internal _pendingQueueIds;

    /// @notice Mapping to efficiently find the index of a queue ID in pendingQueueIds (index + 1)
    mapping(bytes32 queueId => uint256) private _pendingQueueIdIndex;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to restrict functions to authorized queue managers OR the bridge router itself.
     * The bridge router needs auth for potential confirmation transactions.
     */
    modifier onlyQueueManagerAuth() {
        if (!isQueueManager[msg.sender] && msg.sender != bridgeRouter) {
            revert CallerNotQueueManager();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _accessManager,
        address _initialBridgeRouter,
        address _initialQueueManager
    ) DeploymentAccessManaged(msg.sender, _accessManager) {
        if (_initialQueueManager == address(0)) revert InvalidQueueManager(); // Use error for initial manager too

        bridgeRouter = _initialBridgeRouter;
        emit BridgeRouterUpdated(_initialBridgeRouter);

        isQueueManager[_initialQueueManager] = true;
        emit QueueManagerAdded(_initialQueueManager);
    }

    /*//////////////////////////////////////////////////////////////
                       QUEUEING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeQueue
    /// @notice No payment required at queue time. Originator must pre-approve this contract for token transfers.
    function queueTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    ) external onlyQueueManagerAuth returns (bytes32 queueId) {
        if (asset == address(0) || amount == 0 || recipient == address(0))
            revert InvalidParams();

        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), _queueNonce++)
        );

        queuedTransfers[queueId] = QueuedTransfer({
            destinationChainId: destinationChainId,
            asset: asset,
            amount: amount,
            recipient: recipient,
            originator: msg.sender, // The queue manager is responsible for ensuring approvals
            operationId: bytes32(0)
        });
        queueIdToOperationType[queueId] = BridgeTypes
            .OperationType
            .TRANSFER_ASSET;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        _pendingQueueIds.push(queueId);
        _pendingQueueIdIndex[queueId] = _pendingQueueIds.length;

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.TRANSFER_ASSET,
            msg.sender,
            destinationChainId
        );
        return queueId;
    }

    /// @inheritdoc IBridgeQueue
    /// @notice No payment required at queue time.
    function queueReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams
    ) external onlyQueueManagerAuth returns (bytes32 queueId) {
        if (dstContract == address(0)) revert InvalidParams();

        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), _queueNonce++)
        );

        queuedReadStates[queueId] = QueuedReadState({
            dstChainId: dstChainId,
            dstContract: dstContract,
            selector: selector,
            readParams: readParams,
            originator: msg.sender,
            operationId: bytes32(0)
        });
        queueIdToOperationType[queueId] = BridgeTypes.OperationType.READ_STATE;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        _pendingQueueIds.push(queueId);
        _pendingQueueIdIndex[queueId] = _pendingQueueIds.length;

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.READ_STATE,
            msg.sender,
            dstChainId
        );
        return queueId;
    }

    /// @inheritdoc IBridgeQueue
    /// @notice No payment required at queue time.
    function queueSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message
    ) external onlyQueueManagerAuth returns (bytes32 queueId) {
        if (recipient == address(0)) revert InvalidParams();

        queueId = keccak256(
            abi.encodePacked(block.chainid, address(this), _queueNonce++)
        );

        queuedMessages[queueId] = QueuedMessage({
            destinationChainId: destinationChainId,
            recipient: recipient,
            message: message,
            originator: msg.sender,
            operationId: bytes32(0)
        });
        queueIdToOperationType[queueId] = BridgeTypes.OperationType.MESSAGE;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;

        _pendingQueueIds.push(queueId);
        _pendingQueueIdIndex[queueId] = _pendingQueueIds.length;

        emit OperationQueued(
            queueId,
            BridgeTypes.OperationType.MESSAGE,
            msg.sender,
            destinationChainId
        );
        return queueId;
    }

    /*//////////////////////////////////////////////////////////////
                       QUEUE EXECUTION FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeQueue
    /// @notice Keeper pays required fees via msg.value and supplies adapter options.
    function executeQueuedOperation(
        bytes32 queueId,
        BridgeTypes.BridgeOptions calldata options
    ) external payable nonReentrant returns (bytes32 operationId) {
        uint256 index = _pendingQueueIdIndex[queueId];
        if (index == 0) revert QueueIdNotFound();
        if (queueIdToStatus[queueId] != BridgeTypes.OperationStatus.QUEUED)
            revert OperationNotQueued();

        BridgeTypes.OperationType opType = queueIdToOperationType[queueId];
        address executor = msg.sender;
        address router = bridgeRouter;
        if (router == address(0)) revert InvalidBridgeRouter();

        // Get quote from the router based on stored data
        uint256 totalNativeFee;

        // Execute operation based on type
        if (opType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            QueuedTransfer storage transferData = queuedTransfers[queueId];

            // Get quote, ignore token fee
            (totalNativeFee, , ) = IBridgeRouter(router).quote(
                transferData.destinationChainId,
                transferData.asset,
                transferData.amount,
                options,
                opType
            );
            if (msg.value < totalNativeFee) revert InsufficientFee();

            // Transfer assets from originator to this contract
            IERC20(transferData.asset).safeTransferFrom(
                transferData.originator,
                address(this),
                transferData.amount
            );

            // Approve router
            IERC20(transferData.asset).approve(router, transferData.amount);

            BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
                .ExecuteTransferParams({
                    destinationChainId: transferData.destinationChainId,
                    asset: transferData.asset,
                    amount: transferData.amount,
                    recipient: transferData.recipient,
                    originator: transferData.originator,
                    keeper: msg.sender,
                    options: options
                });

            // Execute with keeper's payment
            operationId = IBridgeRouter(router).executeTransferAssets{
                value: totalNativeFee
            }(params);

            // Clean up approval
            IERC20(transferData.asset).approve(router, 0);
        } else if (opType == BridgeTypes.OperationType.READ_STATE) {
            QueuedReadState storage readData = queuedReadStates[queueId];

            // Get quote, ignore token fee
            (totalNativeFee, , ) = IBridgeRouter(router).quote(
                readData.dstChainId,
                address(0),
                0,
                options,
                opType
            );
            if (msg.value < totalNativeFee) revert InsufficientFee();

            BridgeTypes.ExecuteReadStateParams memory params = BridgeTypes
                .ExecuteReadStateParams({
                    dstChainId: readData.dstChainId,
                    dstContract: readData.dstContract,
                    selector: readData.selector,
                    readParams: readData.readParams,
                    originator: readData.originator,
                    keeper: executor, // Add missing keeper field
                    options: options
                });

            // Execute with keeper's payment
            operationId = IBridgeRouter(router).executeReadState{
                value: totalNativeFee
            }(params);
        } else if (opType == BridgeTypes.OperationType.MESSAGE) {
            QueuedMessage storage messageData = queuedMessages[queueId];

            // Get quote, ignore token fee
            (totalNativeFee, , ) = IBridgeRouter(router).quote(
                messageData.destinationChainId,
                address(0),
                0,
                options,
                opType
            );
            if (msg.value < totalNativeFee) revert InsufficientFee();

            BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
                .ExecuteSendMessageParams({
                    destinationChainId: messageData.destinationChainId,
                    recipient: messageData.recipient,
                    message: messageData.message,
                    originator: messageData.originator,
                    keeper: executor, // Add missing keeper field
                    options: options
                });

            // Execute with keeper's payment
            operationId = IBridgeRouter(router).executeSendMessage{
                value: totalNativeFee
            }(params);
        } else {
            revert UnknownOperationType();
        }

        // --- Success Path ---
        operationIdToQueueId[operationId] = queueId;
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.SENT;

        // Store operation ID in the appropriate struct
        if (opType == BridgeTypes.OperationType.TRANSFER_ASSET) {
            queuedTransfers[queueId].operationId = operationId;
        } else if (opType == BridgeTypes.OperationType.READ_STATE) {
            queuedReadStates[queueId].operationId = operationId;
        } else if (opType == BridgeTypes.OperationType.MESSAGE) {
            queuedMessages[queueId].operationId = operationId;
        }

        // Remove from pending queue
        _removePendingId(queueId, index - 1);

        // Refund any excess native fee to the keeper
        if (msg.value > totalNativeFee) {
            (bool success, ) = executor.call{value: msg.value - totalNativeFee}(
                ""
            );
            if (!success) revert RefundFailed();
        }

        emit OperationExecuted(queueId, operationId, executor);

        return operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _removePendingId(bytes32 queueId, uint256 index) internal {
        uint256 lastIndex = _pendingQueueIds.length - 1;
        if (index != lastIndex) {
            bytes32 lastId = _pendingQueueIds[lastIndex];
            _pendingQueueIds[index] = lastId;
            _pendingQueueIdIndex[lastId] = index + 1;
        }
        _pendingQueueIds.pop();
        _pendingQueueIdIndex[queueId] = 0;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeQueue
    function getPendingQueueCount() external view returns (uint256) {
        return _pendingQueueIds.length;
    }

    /// @inheritdoc IBridgeQueue
    function getPendingQueueIdAtIndex(
        uint256 index
    ) external view returns (bytes32) {
        return _pendingQueueIds[index];
    }

    /// @inheritdoc IBridgeQueue
    function pendingQueueIds() external view returns (bytes32[] memory) {
        return _pendingQueueIds;
    }

    /// @inheritdoc IBridgeQueue
    function getOperationStatus(
        bytes32 queueId
    ) external view returns (BridgeTypes.OperationStatus) {
        // If still in queue, return QUEUED
        if (_pendingQueueIdIndex[queueId] > 0) {
            return BridgeTypes.OperationStatus.QUEUED;
        }

        // Otherwise check BridgeRouter status
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
            try
                IBridgeRouter(bridgeRouter).getOperationStatus(operationId)
            returns (BridgeTypes.OperationStatus status) {
                return status;
            } catch {
                return BridgeTypes.OperationStatus.FAILED;
            }
        }
        return BridgeTypes.OperationStatus.FAILED;
    }

    /*//////////////////////////////////////////////////////////////
                           ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IBridgeQueue
    function setBridgeRouter(
        address _newBridgeRouter
    ) external onlyControllerOrGovernor {
        if (_newBridgeRouter == address(0)) revert InvalidBridgeRouter();

        // Verify that the new router supports the required interface
        try
            IBridgeRouter(_newBridgeRouter).supportsInterface(
                type(IBridgeRouter).interfaceId
            )
        returns (bool routerSupported) {
            if (!routerSupported) revert InvalidBridgeRouter();
        } catch {
            revert InvalidBridgeRouter();
        }

        bridgeRouter = _newBridgeRouter;
        emit BridgeRouterUpdated(_newBridgeRouter);
    }

    /// @inheritdoc IBridgeQueue
    function addQueueManager(
        address manager
    ) external onlyControllerOrGovernor {
        if (manager == address(0)) revert InvalidQueueManager();
        if (!isQueueManager[manager]) {
            isQueueManager[manager] = true;
            emit QueueManagerAdded(manager);
        }
    }

    /// @inheritdoc IBridgeQueue
    function removeQueueManager(
        address manager
    ) external onlyControllerOrGovernor {
        if (manager == address(0)) revert InvalidQueueManager(); // Also check for zero address on removal
        if (isQueueManager[manager]) {
            isQueueManager[manager] = false;
            emit QueueManagerRemoved(manager);
        }
    }

    /// @inheritdoc IBridgeQueue
    function dequeueOperation(
        bytes32 queueId
    ) external onlyGovernor nonReentrant {
        uint256 index = _pendingQueueIdIndex[queueId];
        if (index == 0) revert QueueIdNotFound();
        if (queueIdToStatus[queueId] != BridgeTypes.OperationStatus.QUEUED)
            revert OperationNotQueued();

        // If this is a transfer operation, notify the originator to reset inflight assets
        if (
            queueIdToOperationType[queueId] ==
            BridgeTypes.OperationType.TRANSFER_ASSET
        ) {
            address originator = queuedTransfers[queueId].originator;
            // Check if originator supports IInflightAssetTracking interface before calling updateInflightAssets
            if (originator.code.length > 0) {
                try
                    IERC165(originator).supportsInterface(
                        type(IInflightAssetTracking).interfaceId
                    )
                returns (bool supported) {
                    if (supported) {
                        try
                            IInflightAssetTracking(originator)
                                .updateInflightAssets(0)
                        {} catch {
                            // Ignore failures in updateInflightAssets
                        }
                    }
                } catch {
                    // Originator doesn't support ERC165 or IInflightAssetTracking, ignore
                }
            }
        }

        _removePendingId(queueId, index - 1);
        queueIdToStatus[queueId] = BridgeTypes.OperationStatus.FAILED; // Mark as failed since dequeued

        emit OperationDequeued(queueId, msg.sender); // Governor initiated dequeue
    }

    /// @inheritdoc IBridgeQueue
    function recoverFunds(
        address token,
        address recipient,
        uint256 amount
    ) external onlyGovernor {
        if (recipient == address(0)) revert InvalidParams();

        if (token == NATIVE_PSEUDO_ADDRESS) {
            uint256 amountToRecover = amount == 0
                ? address(this).balance
                : amount;
            if (address(this).balance < amountToRecover)
                revert InsufficientBalance();
            (bool success, ) = payable(recipient).call{value: amountToRecover}(
                ""
            );
            if (!success) revert RefundFailed();
            emit FundsRecovered(token, recipient, amountToRecover);
        } else {
            IERC20 erc20Token = IERC20(token);
            uint256 amountToRecover = amount == 0
                ? erc20Token.balanceOf(address(this))
                : amount;
            erc20Token.safeTransfer(recipient, amountToRecover);
            emit FundsRecovered(token, recipient, amountToRecover);
        }
    }

    // --- Fallback/Receive ---
    receive() external payable {}
    fallback() external payable {}
}
