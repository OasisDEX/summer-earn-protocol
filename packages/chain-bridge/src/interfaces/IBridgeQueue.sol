// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IBridgeRouter} from "./IBridgeRouter.sol";

/**
 * @title IBridgeQueue
 * @notice Interface for the BridgeQueue contract.
 * @dev Defines the external functions, events, and errors for queueing and managing cross-chain operations.
 */
interface IBridgeQueue {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the associated BridgeRouter address is updated.
     * @param newBridgeRouter The address of the new BridgeRouter contract.
     */
    event BridgeRouterUpdated(address indexed newBridgeRouter);

    /**
     * @notice Emitted when a new queue manager address is authorized.
     * @param manager The address of the newly added queue manager.
     */
    event QueueManagerAdded(address indexed manager);

    /**
     * @notice Emitted when a queue manager address authorization is revoked.
     * @param manager The address of the removed queue manager.
     */
    event QueueManagerRemoved(address indexed manager);

    /**
     * @notice Emitted when a queued operation is successfully submitted to the BridgeRouter for execution.
     * @param queueId The unique identifier for the queued operation.
     * @param operationId The identifier returned by the BridgeRouter for the specific execution attempt.
     * @param executor The address (keeper) that triggered the execution.
     */
    event OperationExecuted(
        bytes32 indexed queueId,
        bytes32 indexed operationId,
        address indexed executor
    );

    /**
     * @notice Emitted when an operation is manually removed from the queue by an admin.
     * @param queueId The unique identifier of the dequeued operation.
     * @param remover The address (admin/governor) that performed the removal.
     */
    event OperationDequeued(bytes32 indexed queueId, address indexed remover);

    /**
     * @notice Emitted when an attempt to execute a queued operation via the BridgeRouter fails.
     * @dev The operation remains in the queue after this event.
     * @param queueId The unique identifier of the operation that failed execution.
     * @param executor The address (keeper) that attempted the execution.
     * @param reason The revert reason or error data from the failed router call.
     */
    event QueueExecutionFailed(
        bytes32 indexed queueId,
        address indexed executor,
        bytes reason
    );

    /**
     * @notice Emitted when funds (native or ERC20) are recovered from the contract by the governor.
     * @param token The address of the token recovered (0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for native).
     * @param recipient The address receiving the recovered funds.
     * @param amount The amount of funds recovered.
     */
    event FundsRecovered(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    /* @notice Operation queued for later execution.
     * @dev This event is emitted when a new operation is queued.
     * @param queueId The unique identifier for the queued operation.
     * @param operationType The type of operation being queued.
     * @param originator The address that requested the operation via the queue manager.
     * @param destinationChainId The chain ID of the destination chain for the operation.
     */
    event OperationQueued(
        bytes32 indexed queueId,
        BridgeTypes.OperationType indexed operationType,
        address indexed originator, // The manager who queued it
        uint16 destinationChainId
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reverts when attempting to set or use an invalid (zero) BridgeRouter address.
    error InvalidBridgeRouter();
    /// @notice Reverts when attempting to add an invalid (zero) QueueManager address.
    error InvalidQueueManager();
    /// @notice Reverts when a function restricted to queue managers or the bridge router is called by an unauthorized address.
    error CallerNotQueueManager();
    /// @notice Reverts when function arguments are invalid (e.g., zero address, zero amount).
    error InvalidParams();
    /// @notice Reverts when the provided native fee (msg.value) is less than the required fee quoted by the router.
    error InsufficientFee();
    /// @notice Reverts when a refund fails.
    error RefundFailed();
    /// @notice Reverts when trying to execute or dequeue an operation with a queue ID that is not found or not in the expected state (e.g., not pending).
    error QueueIdNotFound();
    /// @notice Reverts when trying to execute or dequeue an operation that is not in the 'QUEUED' status.
    error OperationNotQueued();
    /// @notice Reverts if an operation is attempted on a queue ID that has already been processed or is in a non-actionable state.
    error AlreadyProcessed();
    /// @notice Indicates a failure during the call to the BridgeRouter's execution function (used internally, surfaced as QueueExecutionFailed event).
    error RouterExecutionFailed();
    /// @notice Reverts when attempting to withdraw more native tokens or ERC20 tokens than the contract holds.
    error InsufficientBalance();
    /// @notice Reverts when an unknown or unsupported operation type is encountered during execution.
    error UnknownOperationType();

    /*//////////////////////////////////////////////////////////////
                       EXTERNAL/PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the associated BridgeRouter contract.
     */
    function bridgeRouter() external view returns (address);

    /**
     * @notice Checks if an address is an authorized queue manager.
     * @param account The address to check.
     * @return True if the address is an authorized manager, false otherwise.
     */
    function isQueueManager(address account) external view returns (bool);

    /**
     * @notice Returns the details of a queued asset transfer operation.
     * @param queueId The ID of the queued operation.
     * @return destinationChainId Destination chain ID.
     * @return asset Address of the ERC20 token being transferred.
     * @return amount Amount of the token being transferred.
     * @return recipient Address receiving the asset on the destination chain.
     * @return options Bridge options used for this transfer.
     * @return originator Address that requested the transfer via the queue manager. Must pre-approve this contract for 'amount' of 'asset'.
     * @return operationId ID returned by the bridge adapter upon execution, or zero if not executed.
     */
    function queuedTransfers(
        bytes32 queueId
    )
        external
        view
        returns (
            uint16 destinationChainId,
            address asset,
            uint256 amount,
            address recipient,
            BridgeTypes.BridgeOptions memory options,
            address originator,
            bytes32 operationId
        );

    /**
     * @notice Returns the details of a queued state read operation.
     * @param queueId The ID of the queued operation.
     * @return dstChainId Destination chain ID.
     * @return dstContract Address of the contract to call on the destination chain.
     * @return selector Function selector to call on the destination contract.
     * @return readParams Encoded parameters for the destination call.
     * @return options Bridge options used for this read.
     * @return originator Address that requested the read via the queue manager.
     * @return operationId ID returned by the bridge adapter upon execution, or zero if not executed.
     */
    function queuedReadStates(
        bytes32 queueId
    )
        external
        view
        returns (
            uint16 dstChainId,
            address dstContract,
            bytes4 selector,
            bytes memory readParams,
            BridgeTypes.BridgeOptions memory options,
            address originator,
            bytes32 operationId
        );

    /**
     * @notice Returns the details of a queued message sending operation.
     * @param queueId The ID of the queued operation.
     * @return destinationChainId Destination chain ID.
     * @return recipient Address receiving the message on the destination chain.
     * @return message The arbitrary message data to be sent.
     * @return options Bridge options used for this message.
     * @return originator Address that requested the message via the queue manager.
     * @return operationId ID returned by the bridge adapter upon execution, or zero if not executed.
     */
    function queuedMessages(
        bytes32 queueId
    )
        external
        view
        returns (
            uint16 destinationChainId,
            address recipient,
            bytes memory message,
            BridgeTypes.BridgeOptions memory options,
            address originator,
            bytes32 operationId
        );

    /**
     * @notice Returns the type of operation associated with a given queue ID.
     * @param queueId The ID of the operation.
     * @return The type of operation (MESSAGE, READ_STATE, TRANSFER_ASSET).
     */
    function queueIdToOperationType(
        bytes32 queueId
    ) external view returns (BridgeTypes.OperationType);

    /**
     * @notice Returns the current status of a given queue ID within the queue contract itself.
     * @dev To get the potentially more up-to-date status after execution, use `getOperationStatus`.
     * @param queueId The ID of the operation.
     * @return The status (QUEUED, PENDING, FAILED, etc.).
     */
    function queueIdToStatus(
        bytes32 queueId
    ) external view returns (BridgeTypes.OperationStatus);

    /**
     * @notice Returns the queue ID associated with a bridge adapter's operation ID.
     * @param operationId The operation ID returned by the bridge adapter upon execution.
     * @return queueId The corresponding queue ID used within this contract.
     */
    function operationIdToQueueId(
        bytes32 operationId
    ) external view returns (bytes32 queueId);

    /**
     * @notice Returns the array of queue IDs currently pending execution.
     */
    function pendingQueueIds() external view returns (bytes32[] memory);

    /**
     * @notice Queues an asset transfer operation.
     * @dev Requires caller to be an authorized `queueManager`. No fee required at queue time.
     *      The `originator` (msg.sender) must ensure the BridgeQueue contract is approved to spend the `asset` before execution.
     * @param destinationChainId The target chain ID.
     * @param asset The ERC20 token address to transfer.
     * @param amount The amount of the token to transfer.
     * @param recipient The address to receive the tokens on the destination chain.
     * @param options Bridging options (adapter, gas limits, etc.).
     * @return queueId The unique ID assigned to this queued operation.
     */
    function queueTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external returns (bytes32 queueId);

    /**
     * @notice Queues a cross-chain state read operation.
     * @dev Requires caller to be an authorized `queueManager`. No fee required at queue time.
     * @param dstChainId The target chain ID.
     * @param dstContract The contract address to call on the destination chain.
     * @param selector The function selector to call.
     * @param readParams The encoded parameters for the function call.
     * @param options Bridging options (adapter, gas limits, etc.).
     * @return queueId The unique ID assigned to this queued operation.
     */
    function queueReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata options
    ) external returns (bytes32 queueId);

    /**
     * @notice Queues a cross-chain message sending operation.
     * @dev Requires caller to be an authorized `queueManager`. No fee required at queue time.
     * @param destinationChainId The target chain ID.
     * @param recipient The address to receive the message on the destination chain.
     * @param message The arbitrary message data to send.
     * @param options Bridging options (adapter, gas limits, etc.).
     * @return queueId The unique ID assigned to this queued operation.
     */
    function queueSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external returns (bytes32 queueId);

    /**
     * @notice Executes a pending queued operation by calling the associated BridgeRouter.
     * @dev Can be called by anyone (typically a keeper). Requires the operation to be in 'QUEUED' status.
     *      Requires `msg.value` to cover the bridging fee quoted by the router. Handles asset transfers/approvals.
     * @param queueId The ID of the operation to execute.
     * @return operationId The ID returned by the BridgeRouter upon successful submission, or bytes32(0) if submission fails.
     */
    function executeQueuedOperation(
        bytes32 queueId
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Returns the total number of operations currently in the pending queue.
     */
    function getPendingQueueCount() external view returns (uint256);

    /**
     * @notice Returns the queue ID at a specific index in the pending queue array.
     * @param index The index in the `pendingQueueIds` array.
     * @return The queue ID at that index.
     */
    function getPendingQueueIdAtIndex(
        uint256 index
    ) external view returns (bytes32);

    /**
     * @notice Gets the most up-to-date status of a queued operation.
     * @dev If the operation has been executed (has an operationId), this function queries the BridgeRouter for the status.
     *      Otherwise, it returns the status stored within the BridgeQueue contract.
     * @param queueId The ID of the operation.
     * @return The current status of the operation.
     */
    function getOperationStatus(
        bytes32 queueId
    ) external view returns (BridgeTypes.OperationStatus);

    /**
     * @notice Allows the governor to set a new BridgeRouter contract address.
     * @param _newBridgeRouter The address of the new BridgeRouter.
     */
    function setBridgeRouter(address _newBridgeRouter) external;

    /**
     * @notice Allows the governor to authorize a new queue manager address.
     * @param manager The address to authorize as a queue manager.
     */
    function addQueueManager(address manager) external;

    /**
     * @notice Allows the governor to revoke authorization for a queue manager address.
     * @param manager The address to remove from the authorized queue managers.
     */
    function removeQueueManager(address manager) external;

    /**
     * @notice Allows the governor to remove an operation from the pending queue.
     * @dev This is intended for stuck or invalid operations.
     * @param queueId The ID of the operation to dequeue.
     */
    function dequeueOperation(bytes32 queueId) external;

    /**
     * @notice Allows the governor to withdraw surplus funds (native or ERC20) from the contract.
     * @param token The address of the token to withdraw. Use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for native currency.
     * @param recipient The address to receive the funds.
     * @param amount The amount of funds to withdraw. If 0, withdraws the entire balance of the specified token.
     */
    function recoverFunds(
        address token,
        address recipient,
        uint256 amount
    ) external;
}
