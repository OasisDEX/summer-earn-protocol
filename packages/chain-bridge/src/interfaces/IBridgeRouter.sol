// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBridgeRouter
 * @notice Interface for the BridgeRouter contract that coordinates cross-chain operations
 * @dev This interface defines all external functions for interacting with bridge adapters.
 *      Access control is managed through ProtocolAccessManaged, using roles from the
 *      protocol's central access management system.
 */
interface IBridgeRouter {
    /*//////////////////////////////////////////////////////////////
                               EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new adapter is registered
    event AdapterRegistered(address indexed adapter);

    /// @notice Emitted when an adapter is removed
    event AdapterRemoved(address indexed adapter);

    /// @notice Emitted when a transfer is initiated
    event TransferInitiated(
        bytes32 indexed operationId,
        uint16 destinationChainId,
        address indexed asset,
        uint256 amount,
        address indexed recipient,
        address adapter
    );

    /// @notice Emitted when a message is initiated
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

    /// @notice Emitted when a read request is initiated
    event ReadRequestInitiated(
        bytes32 indexed operationId,
        uint16 sourceChainId,
        bytes sourceContract,
        bytes4 selector,
        bytes params,
        address adapter
    );

    /// @notice Emitted when sending a confirmation message fails
    event ConfirmationFailed(bytes32 indexed operationId);

    /// @notice Emitted when an operation status is manually updated
    event ManualStatusUpdate(
        bytes32 indexed operationId,
        BridgeTypes.OperationStatus status,
        address updater
    );

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

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when an adapter is already registered
    error AdapterAlreadyRegistered();

    /// @notice Error thrown when an adapter is not registered
    error UnknownAdapter();

    /// @notice Error thrown when a caller is not authorized
    error Unauthorized();

    /// @notice Error thrown when the receiver rejects a call
    error ReceiverRejectedCall();

    /// @notice Error thrown when invalid parameters are provided
    error InvalidParams();

    /// @notice Error thrown when trying to update status in invalid direction
    error InvalidStatusProgression();

    /// @notice Thrown when the contract is paused
    error Paused();

    /// @notice Thrown when the provided fee is insufficient
    error InsufficientFee();

    /// @notice Thrown when no suitable adapter is found for a transfer
    error NoSuitableAdapter();

    /// @notice Thrown when a transfer fails
    error TransferFailed();

    /// @notice Thrown when an adapter doesn't support a requested operation
    error UnsupportedAdapterOperation();

    /// @notice Thrown when there are insufficient funds in the router
    error InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                        USER BRIDGE OPERATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer an asset to a destination chain
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param recipient Address of the recipient on the destination chain
     * @param options Additional options for the transfer
     * @return operationId Unique ID to track this operation
     * @dev This function selects the best adapter for the transfer based on user preferences,
     *      transfers tokens from sender to the router, and initiates the cross-chain transfer
     */
    function transferAssets(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Read data from another chain (async operation)
     * @param sourceChainId ID of the source chain
     * @param sourceContract Address of the contract on the source chain
     * @param selector Function selector to call
     * @param params Parameters for the function call
     * @param options Additional options for the read operation
     * @return operationId Unique ID to track this read request
     * @dev This function initiates a cross-chain read operation that will be completed
     *      asynchronously when the response is received from the source chain
     */
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Estimate the fee required for a cross-chain transfer
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param options Additional options for the transfer
     * @return nativeFee Fee in native token
     * @return tokenFee Fee in the asset token
     * @return selectedAdapter Address of the selected adapter
     * @dev This function provides a quote for the fees needed to complete a transfer
     *      without actually initiating the transfer
     */
    function quote(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter);

    /**
     * @notice Send a general cross-chain message
     * @param destinationChainId ID of the destination chain
     * @param recipient Address of the recipient on the destination chain
     * @param message The message data to be sent cross-chain
     * @param options Additional options for the message
     * @return operationId Unique ID to track this message
     * @dev This function selects the best adapter for messaging based on user preferences
     *      and initiates the cross-chain message transfer
     */
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receive and deliver read responses from adapters
     * @param operationId Unique identifier for the read request
     * @param resultData The data returned from the source chain
     * @dev This function is called by bridge adapters when a read request has been completed
     *      It forwards the result to the original requester
     */
    function deliverReadResponse(
        bytes32 operationId,
        bytes calldata resultData
    ) external;

    /**
     * @notice Update the status of an operation (called by adapters)
     * @param operationId ID of the operation to update
     * @param status New status of the operation
     * @dev This function can only be called by the adapter that initiated the operation
     */
    function updateOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external;

    /**
     * @notice Update the status of a received operation (called by adapters)
     * @param requestId ID of the received request to update
     * @param status New status of the received request
     * @dev This function can only be called by the adapter that received the request
     */
    function updateReceiveStatus(
        bytes32 requestId,
        BridgeTypes.OperationStatus status
    ) external;

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the status of an operation
     * @param operationId ID of the operation
     * @return Status of the operation
     * @dev Returns the current status of a cross-chain operation (transfer, message, or read)
     */
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus);

    /**
     * @notice Get the best adapter for a specific transfer
     * @param chainId ID of the destination/source chain
     * @param asset Address of the asset (address(0) for native/reads)
     * @param amount Amount to transfer (0 for reads)
     * @return bestAdapter Address of the best adapter
     * @dev Determines the most suitable adapter based on fees:
     *      - For transfers, selects the adapter with the lowest fee.
     *      - For read operations (asset=address(0) or amount=0), returns first valid adapter.
     */
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount
    ) external view returns (address bestAdapter);

    /**
     * @notice Get the best adapter with explicit operation type
     * @param chainId ID of the destination/source chain
     * @param asset Address of the asset (address(0) for non-asset operations)
     * @param amount Amount to transfer (0 for non-asset operations)
     * @param forStateRead Whether this is for a state read operation
     * @return bestAdapter Address of the best adapter
     * @dev Extended version that allows specifying state read operations explicitly
     */
    function getBestAdapter(
        uint16 chainId,
        address asset,
        uint256 amount,
        bool forStateRead
    ) external view returns (address bestAdapter);

    /**
     * @notice Get the best adapter for state read operations
     * @param chainId Source chain ID to read from
     * @return The address of the best adapter for state reading
     */
    function getBestAdapterForStateRead(
        uint16 chainId
    ) external view returns (address);

    /**
     * @notice Get all registered adapters
     * @return adapterList Array of registered adapter addresses
     * @dev Returns a list of all currently registered bridge adapters
     */
    function getAdapters() external view returns (address[] memory adapterList);

    /**
     * @notice Check if an address is a registered adapter
     * @param adapter Address to check
     * @return isValid True if the address is a registered adapter
     * @dev Verifies whether the given address is a registered bridge adapter
     */
    function isValidAdapter(address adapter) external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                         GOVERNANCE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Register a new bridge adapter
     * @param adapter Address of the adapter to register
     * @dev Only callable by accounts with the GOVERNOR_ROLE in the ProtocolAccessManager
     */
    function registerAdapter(address adapter) external;

    /**
     * @notice Remove a bridge adapter
     * @param adapter Address of the adapter to remove
     * @dev Only callable by accounts with the GOVERNOR_ROLE in the ProtocolAccessManager
     */
    function removeAdapter(address adapter) external;

    /**
     * @notice Pause all bridge operations
     * @dev Can be called by accounts with either the GOVERNOR_ROLE or GUARDIAN_ROLE
     *      in the ProtocolAccessManager. This allows for emergency pausing by guardians.
     */
    function pause() external;

    /**
     * @notice Unpause bridge operations
     * @dev Only callable by accounts with the GOVERNOR_ROLE in the ProtocolAccessManager.
     *      Guardians can pause but cannot unpause the system, ensuring proper governance
     *      approval is required to resume operations after an emergency pause.
     */
    function unpause() external;

    /**
     * @notice Deliver a message received from a source chain to its recipient
     * @param operationId ID of the message
     * @param message The message data
     * @param recipient Address of the recipient
     * @dev This function is called by bridge adapters when a message has been received
     *      It forwards the message to the intended recipient
     */
    function deliverMessage(
        bytes32 operationId,
        bytes memory message,
        address recipient
    ) external;

    /**
     * @notice Notify the router when a transfer is received on the destination chain
     * @param operationId ID of the transfer that was received
     * @param asset Address of the asset that was received
     * @param amount Amount of the asset that was received
     * @param recipient Address that received the assets
     * @param sourceChainId ID of the chain where the transfer originated
     * @dev This function is called by adapters on the destination chain when they receive assets
     *      It automatically attempts to send a confirmation back to the source chain
     */
    function notifyTransferReceived(
        bytes32 operationId,
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId
    ) external;

    /**
     * @notice Receive a confirmation message from a destination chain
     * @param operationId ID of the operation being confirmed
     * @param status The final status of the operation
     * @dev This function is called by adapters when they receive a confirmation message
     */
    function receiveConfirmation(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external;

    /**
     * @notice Allows recovery of operations when automated confirmations fail
     * @param operationId ID of the operation to update
     * @param status New status to set
     * @dev Can only be called by authorized keepers or governance
     */
    function recoverOperationStatus(
        bytes32 operationId,
        BridgeTypes.OperationStatus status
    ) external;
}
