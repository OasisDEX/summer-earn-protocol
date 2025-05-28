// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title IBridgeRouter
 * @notice Interface for the BridgeRouter contract that coordinates cross-chain operations
 * @dev Defines external functions for adapter callbacks, BridgeQueue calls,
 *      and governance. Access control is managed through ProtocolAccessManaged.
 *      User-initiated operations are intended to go through the BridgeQueue.
 */
interface IBridgeRouter is IERC165 {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new adapter is registered
    event AdapterRegistered(address indexed adapter);

    /// @notice Emitted when an adapter is removed
    event AdapterRemoved(address indexed adapter);

    /// @notice Emitted when a transfer is initiated by the BridgeQueue
    event TransferInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId,
        address indexed asset,
        uint256 amount,
        address indexed recipient,
        address adapter
    );

    /// @notice Emitted when a message is initiated by the BridgeQueue
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

    /// @notice Emitted when a read request is initiated by the BridgeQueue
    event ReadRequestInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId, // Corrected from sourceChainId for clarity
        address dstContract,
        bytes4 selector,
        bytes readParams,
        address adapter
    );

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

    /// @notice Emitted when funds are recovered from the router by governance
    event RouterFundsRecovered(address indexed recipient, uint256 amount);

    /// @notice Emitted when the default gas limit is updated
    event DefaultGasLimitUpdated(uint256 newDefaultGasLimit);

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
    /// @notice Error thrown when an invalid bridge queue address is provided
    error InvalidBridgeQueue();

    /*//////////////////////////////////////////////////////////////
                      BRIDGE QUEUE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute asset transfer initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter.
     *      The implementation should pass the provided `originator` to the internal execution logic and adapter.
     * @param params Struct containing all parameters for the transfer execution.
     * @return operationId Unique operation ID.
     */
    function executeTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Execute state read initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter.
     *      The `originator` parameter represents the original requester; the implementation determines how the response is routed (e.g., back to the originator, or potentially to the BridgeQueue itself depending on the design).
     * @param params Struct containing all parameters for the state read execution.
     * @return operationId Unique operation ID.
     */
    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Execute message send initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter.
     *      The implementation should pass the provided `originator` to the internal execution logic and adapter.
     * @param params Struct containing all parameters for the message send execution.
     * @return operationId Unique operation ID.
     */
    function executeSendMessage(
        BridgeTypes.ExecuteSendMessageParams calldata params
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
     * @param sourceChainId ID of the chain where the data was read from
     * @param resultData The data returned from the destination chain read
     * @dev Called by adapter on the source chain upon receiving the response.
     *      Attempts to forward the result to the original requester. Requires caller == operationToAdapter[operationId].
     */
    function deliverReadResponse(
        bytes32 operationId,
        uint16 sourceChainId,
        bytes calldata resultData
    ) external;

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Estimate the base fee for a bridge operation without executing it.
     * @param destinationChainId ID of the destination/source chain.
     * @param asset Address of the asset (address(0) for non-asset ops).
     * @param amount Amount to transfer (0 for non-asset ops).
     * @param options Bridge options including adapter choice and params.
     * @param operationType Type of operation (MESSAGE, READ_STATE, TRANSFER_ASSET).
     * @return nativeFee Estimated base fee in native currency.
     * @return tokenFee Estimated base fee in the asset token (if applicable).
     * @return selectedAdapter The adapter that would be used for this operation.
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
     * @notice Get the status of an operation
     * @param operationId ID of the operation
     * @return Status of the operation
     */
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus);

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
     * @notice Get the configured BridgeRouter address for a given chain ID
     * @param chainId The chain ID
     * @return routerAddress The configured router address for that chain
     */
    function chainToRouterAddress(
        uint16 chainId
    ) external view returns (address routerAddress);

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
     * @notice Set the BridgeQueue address
     * @param _newBridgeQueue The new BridgeQueue address
     * @dev Governor role required.
     */
    function setBridgeQueue(address _newBridgeQueue) external;

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
     * @dev Governor role required. This is the standard governance rescue mechanism for native tokens.
     */
    function recoverFunds(address recipient, uint256 amount) external;
}
