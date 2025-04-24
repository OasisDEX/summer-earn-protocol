// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title IBridgeRouter
 * @notice Interface for the BridgeRouter contract that coordinates cross-chain operations
 * @dev Defines external functions for user interactions, adapter callbacks, BridgeQueue calls,
 *      and governance. Access control is managed through ProtocolAccessManaged.
 */
interface IBridgeRouter is IERC165 {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new adapter is registered
    event AdapterRegistered(address indexed adapter);

    /// @notice Emitted when an adapter is removed
    event AdapterRemoved(address indexed adapter);

    /// @notice Emitted when a transfer is initiated by a user or BridgeQueue
    event TransferInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId,
        address indexed asset,
        uint256 amount,
        address indexed recipient,
        address adapter
    );

    /// @notice Emitted when a message is initiated by a user or BridgeQueue
    event MessageInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId,
        address indexed recipient,
        address adapter
    );

    /// @notice Emitted when an operation status is updated
    event OperationStatusUpdated(
        bytes32 indexed operationId,
        BridgeTypes.OperationStatus status
    );

    /// @notice Emitted when a transfer is received on the destination chain
    event TransferReceived(
        bytes32 indexed operationId,
        address indexed asset,
        uint256 amount,
        address indexed recipient,
        uint16 sourceChainId
    );

    /// @notice Emitted when a read request is initiated by a user or BridgeQueue
    event ReadRequestInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId, // Corrected from sourceChainId for clarity
        address dstContract,
        bytes4 selector,
        bytes readParams,
        address adapter
    );

    /// @notice Emitted when sending a confirmation message fails
    event ConfirmationFailed(bytes32 indexed operationId);

    /// @notice Emitted when funds are added to the router
    event RouterFundsAdded(address indexed contributor, uint256 amount);

    /// @notice Emitted when funds are removed from the router
    event RouterFundsRemoved(address indexed recipient, uint256 amount);

    /// @notice Emitted when a read response is delivered to the requester
    event ReadResponseDelivered(
        bytes32 indexed operationId,
        address recipient,
        bool delivered
    );

    /// @notice Emitted when a message is delivered to its recipient
    event MessageDelivered(
        bytes32 indexed operationId,
        address recipient,
        bool delivered
    );

    /// @notice Emitted when a chain's router address is updated
    event ChainRouterAddressUpdated(
        uint16 indexed chainId,
        address routerAddress
    );

    /// @notice Emitted when the confirmation gas limit is updated
    event ConfirmationGasLimitUpdated(uint64 newConfirmationGasLimit); // uint64 matches implementation

    /// @notice Emitted when the BridgeQueue address is updated (typically during construction)
    event BridgeQueueUpdated(address indexed newBridgeQueue);

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when an adapter is already registered
    error AdapterAlreadyRegistered();
    /// @notice Error thrown when an adapter is not registered
    error UnknownAdapter();
    /// @notice Error thrown when a caller is not authorized (e.g., not a registered adapter)
    error Unauthorized();
    /// @notice Error thrown when the receiver rejects a call (e.g., in deliverReadResponse)
    error ReceiverRejectedCall(); // Keep, might be useful for callbacks
    /// @notice Error thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Error thrown when trying to update status in invalid direction
    error InvalidStatusProgression();

    /// @notice Error thrown when an invalid status is provided
    error InvalidStatus();

    /// @notice Thrown when the contract is paused
    error Paused();
    /// @notice Thrown when the provided fee is insufficient
    error InsufficientFee();
    /// @notice Thrown when no suitable adapter is found for an operation
    error NoSuitableAdapter();
    /// @notice Thrown when a native token transfer fails (e.g., refund)
    error TransferFailed();
    /// @notice Thrown when an adapter doesn't support a requested operation
    error UnsupportedAdapterOperation();
    /// @notice Thrown when there are insufficient native funds in the router
    error InsufficientBalance();
    /// @notice Error for calls not originating from the configured BridgeQueue
    error OnlyBridgeQueue();
    /// @notice Error when the feeMultiplier is zero, preventing fee calculation
    error InvalidFeeMultiplier();

    /*//////////////////////////////////////////////////////////////
                        USER BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer assets to a destination chain (User initiated)
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param recipient Address on the destination chain to receive the assets
     * @param options Additional options for the transfer (adapter choice, params)
     * @return operationId Unique ID for tracking the transfer
     * @dev Requires msg.value >= total fee (base fee * multiplier). Collects full fee.
     */
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Quote the total fee (including multiplier) for a bridge operation
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset (address(0) for non-asset ops)
     * @param amount Amount of the asset (0 for non-asset ops)
     * @param options Additional options for the operation
     * @param operationType Type of operation (MESSAGE, READ_STATE, TRANSFER_ASSET)
     * @return nativeFee Total fee in the chain's native token (includes multiplier)
     * @return tokenFee Total fee in the transferred token (includes multiplier, if applicable)
     * @return selectedAdapter Address of the adapter that would be used
     */
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.OperationType operationType
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter);

    /**
     * @notice Read data from another chain (User initiated, async)
     * @param dstChainId ID of the destination chain where data resides
     * @param dstContract Address of the contract on the destination chain
     * @param selector Function selector to call on dstContract
     * @param readParams Parameters for the function call
     * @param options Additional options for the read operation
     * @return operationId Unique ID to track this read request
     * @dev Requires msg.value >= total fee (base fee * multiplier). Collects full fee.
     *      Response delivered asynchronously via deliverReadResponse.
     */
    function readState(
        uint16 dstChainId, // Renamed for clarity
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Send a general cross-chain message (User initiated)
     * @param destinationChainId ID of the destination chain
     * @param recipient Address of the recipient on the destination chain
     * @param message The message data to be sent cross-chain
     * @param options Additional options for the message
     * @return operationId Unique ID to track this message
     * @dev Requires msg.value >= total fee (base fee * multiplier). Collects full fee.
     */
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /*//////////////////////////////////////////////////////////////
                      BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute asset transfer initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter (no router fee multiplier applied).
     *      The implementation should pass the provided `originator` to the internal execution logic and adapter.
     * @param destinationChainId Destination chain ID.
     * @param asset Asset address.
     * @param amount Asset amount.
     * @param recipient Recipient address on destination chain.
     * @param originator The original user/contract that requested this via the queue.
     * @param options Bridge options (adapter choice, params) passed from the queue.
     * @return operationId Unique operation ID.
     */
    function executeTransferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Execute state read initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter (no router fee multiplier applied).
     *      The `originator` parameter represents the original requester; the implementation determines how the response is routed (e.g., back to the originator, or potentially to the BridgeQueue itself depending on the design).
     *      The `options` parameter allows the BridgeQueue to specify adapter parameters if needed.
     * @param dstChainId Destination chain ID.
     * @param dstContract Contract address on destination chain.
     * @param selector Function selector.
     * @param readParams Function parameters.
     * @param originator The original user/contract that requested this via the queue.
     * @param options Bridge options (adapter choice, params) passed from the queue.
     * @return operationId Unique operation ID.
     */
    function executeReadState(
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Execute message send initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter (no router fee multiplier applied).
     *      The implementation should pass the provided `originator` to the internal execution logic and adapter.
     * @param destinationChainId Destination chain ID.
     * @param recipient Recipient address on destination chain.
     * @param message Message data.
     * @param originator The original user/contract that requested this via the queue.
     * @param options Bridge options (adapter choice, params) passed from the queue.
     * @return operationId Unique operation ID.
     */
    function executeSendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Update the status of an operation (called by adapters)
     * @param operationId ID of the operation to update
     * @param status New status of the operation
     * @dev Called by the adapter handling the operation on the source chain. Requires caller == operationToAdapter[operationId].
     */
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external;

    /**
     * @notice Update the status of a received message/transfer (called by adapters)
     * @param requestId ID of the received request/operation
     * @param recipient Address of the message recipient (used for event)
     * @param status New status of the received request (e.g., DELIVERED, FAILED)
     * @dev Called by the adapter on the destination chain after attempting delivery. Only adapter can call.
     */
    function updateReceiveStatus(
        bytes32 requestId,
        address recipient,
        BridgeTypes.OperationStatus status
    ) external;

    /**
     * @notice Notify the router that a message or transfer has arrived (called by adapters)
     * @param operationId ID of the message/transfer received
     * @param asset Address of the asset received (address(0) for messages)
     * @param amount Amount of the asset received (0 for messages)
     * @param recipient Address that received the assets/message
     * @param sourceChainId ID of the chain where the operation originated
     * @dev Called by adapter on destination chain upon successful receipt from the bridge protocol.
     *      Sets status to DELIVERED and attempts to send confirmation back. Only adapter can call.
     */
    function notifyMessageReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external;

    /**
     * @notice Deliver read response data (called by adapters)
     * @param operationId Unique identifier for the original read request
     * @param resultData The data returned from the destination chain read
     * @dev Called by adapter on the source chain upon receiving the response.
     *      Attempts to forward the result to the original requester. Requires caller == operationToAdapter[operationId].
     */
    function deliverReadResponse(
        bytes32 operationId,
        bytes calldata resultData
    ) external;

    /**
     * @notice Receive a confirmation message from a destination chain (called by adapters)
     * @param operationId ID of the operation being confirmed (usually as COMPLETED)
     * @param status The final status received from the confirmation message
     * @dev Called by adapter on the source chain when a confirmation message arrives. Only adapter can call.
     */
    function receiveConfirmation(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external;

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the status of an operation
     * @param operationId ID of the operation
     * @return Status of the operation
     */
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus);

    /**
     * @notice Get the best adapter for a specific transfer (deprecated, use typed version)
     * @param chainId ID of the destination/source chain
     * @param asset Address of the asset (address(0) for native/reads/messages)
     * @param amount Amount to transfer (0 for reads/messages)
     * @return bestAdapter Address of the best adapter based on lowest fee (considering multiplier)
     */
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount
    ) external view returns (address bestAdapter);

    /**
     * @notice Get the best adapter with explicit operation type
     * @param chainId ID of the destination/source chain
     * @param asset Address of the asset (address(0) for non-asset ops)
     * @param amount Amount to transfer (0 for non-asset ops)
     * @param operationType Type of operation (MESSAGE, READ_STATE, TRANSFER_ASSET)
     * @return bestAdapter Address of the best adapter based on lowest fee (considering multiplier)
     */
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount,
        BridgeTypes.OperationType operationType
    ) external view returns (address bestAdapter);

    /**
     * @notice Get the best adapter specifically for state read operations
     * @param chainId Destination chain ID to read from
     * @return The address of the best adapter for state reading based on lowest fee (considering multiplier)
     */
    function getBestAdapterForStateRead(
        uint16 chainId
    ) external view returns (address);

    /**
     * @notice Get all registered adapters
     * @return Array of registered adapter addresses
     */
    function getAdapters() external view returns (address[] memory);

    /**
     * @notice Check if an address is a registered adapter
     * @param adapter Address to check
     * @return isValid True if the address is a registered adapter
     */
    function isValidAdapter(address adapter) external view returns (bool);

    /**
     * @notice Get the current balance of native tokens held by the router
     * @return The balance of native tokens
     */
    function getRouterBalance() external view returns (uint256);

    /**
     * @notice Get the current fee multiplier used for calculating total fees for user-initiated ops
     * @return The fee multiplier value (e.g., 200 means 200%)
     */
    function feeMultiplier() external view returns (uint256);

    /**
     * @notice Get the configured BridgeRouter address for a given chain ID
     * @param chainId The chain ID
     * @return routerAddress The configured router address for that chain
     */
    function chainToRouterAddress(
        uint16 chainId
    ) external view returns (address routerAddress);

    /**
     * @notice Get the configured gas limit for sending confirmation messages
     * @return The gas limit value
     */
    function confirmationGasLimit() external view returns (uint64);

    /**
     * @notice Get the configured address of the BridgeQueue contract
     * @return The address of the BridgeQueue
     */
    function bridgeQueue() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new bridge adapter
     * @param adapter Address of the adapter to register
     * @dev Governor role required.
     */
    function registerAdapter(address adapter) external;

    /**
     * @notice Remove a bridge adapter
     * @param adapter Address of the adapter to remove
     * @dev Governor role required.
     */
    function removeAdapter(address adapter) external;

    /**
     * @notice Pause all bridge operations (transfers, reads, messages)
     * @dev Guardian or Governor role required.
     */
    function pause() external;

    /**
     * @notice Unpause bridge operations
     * @dev Governor role required.
     */
    function unpause() external;

    /**
     * @notice Manually recover/update the status of an operation if automated flow failed
     * @param operationId ID of the operation to update
     * @param newStatus New status to set for the operation
     * @dev Governor role required. Use with caution.
     */
    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus newStatus // Renamed param
    ) external;

    /**
     * @notice Update the fee multiplier for user-initiated operations
     * @param newFeeMultiplier New multiplier (e.g., 200 for 200%)
     * @dev Governor role required.
     */
    function setFeeMultiplier(uint256 newFeeMultiplier) external; // Renamed param

    /**
     * @notice Update the default gas limit for sending confirmation messages
     * @param newConfirmationGasLimit New gas limit value
     * @dev Governor role required.
     */
    function setConfirmationGasLimit(uint64 newConfirmationGasLimit) external;

    /**
     * @notice Set the known BridgeRouter address for another chain (used for confirmations)
     * @param chainId The target chain ID
     * @param routerAddress Address of the BridgeRouter contract on that chain
     * @dev Governor role required.
     */
    function setChainRouterAddress(
        uint16 chainId,
        address routerAddress
    ) external;

    /**
     * @notice Withdraw accumulated native tokens (e.g., from fee margins) from the router
     * @param recipient Address to send the native tokens to
     * @param amount Amount of native tokens to withdraw
     * @dev Governor role required.
     */
    function removeRouterFunds(address recipient, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allow anyone to add native funds to the router (e.g., to subsidize confirmation fees)
     * @dev Emits RouterFundsAdded event.
     */
    function addRouterFunds() external payable;
}
