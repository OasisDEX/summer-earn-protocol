// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

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

    /// @notice Emitted when a read request is initiated by the BridgeQueue
    event ReadRequestInitiated(
        // Corrected from sourceChainId for clarity
        bytes32 indexed operationId,
        uint16 destinationChainId,
        address destinationContract,
        bytes4 selector,
        bytes readParams,
        address adapter
    );

    /// @notice Emitted when any cross-chain operation is delivered
    event OperationDelivered(
        bytes32 indexed operationId,
        BridgeTypes.OperationType indexed operationType
    );

    /// @notice Emitted when a chain's router address is updated
    event ChainRouterAddressUpdated(
        uint16 indexed chainId,
        address routerAddress
    );

    /// @notice Emitted when assets (ERC20 or native) are recovered from the router by governance
    /// @dev If `token` is address(0), the recovery represents native ETH.
    event RouterAssetsRecovered(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

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

    /// @notice Error thrown when the originator is not the caller
    error InvalidOriginator();

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

    error UnsupportedOperationType();

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
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /**
     * @notice Execute state read initiated by the BridgeQueue.
     * @dev Requires caller to be the configured BridgeQueue (`onlyBridgeQueue`).
     *      Expects `msg.value` to cover the *base* fee required by the adapter.
     *      The `originator` parameter represents the original requester; the implementation determines how the response
     * is routed (e.g., back to the originator, or potentially to the BridgeQueue itself depending on the design).
     * @param params Struct containing all parameters for the state read execution.
     * @return operationId Unique operation ID.
     */
    function executeReadState(
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
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
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 operationId);

    /*//////////////////////////////////////////////////////////////
                        ADAPTER CALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Single entry-point for inbound asset transfers and messages
     * @dev Called by registered adapters to deliver assets and messages to recipients.
     *      The registry ensures recipients are valid targets.
     *      For assets, transfers tokens and emits TransferReceived.
     *      For messages, calls recipient and emits MessageDelivered.
     * @param operationType Type of operation (MESSAGE, READ_STATE, TRANSFER_ASSET).
     * @param operationPayload Encoded operation payload
     */
    function deliver(
        BridgeTypes.OperationType operationType,
        bytes calldata operationPayload
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
     * @return specifiedAdapter The adapter that was specified in the options.
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
        returns (uint256 nativeFee, uint256 tokenFee, address specifiedAdapter);

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
     * @notice Recover stuck assets (native ETH or ERC20) from the router
     * @param token Address of the ERC20 token to recover; use address(0) for native ETH
     * @param recipient Address to receive the recovered assets
     * @param amount Amount of assets to recover
     * @dev Governor role required. Uses SafeERC20 for token transfers and a low-level call for native ETH.
     */
    function recoverAssets(
        address token,
        address recipient,
        uint256 amount
    ) external;
}
