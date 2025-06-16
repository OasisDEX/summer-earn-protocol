// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ISendAdapter
 * @notice Interface for bridge adapters that can send messages and assets across chains
 * @dev This interface defines methods for initiating various cross-chain operations
 */
interface ISendAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a transfer is initiated through the adapter
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when a message is initiated through the adapter
    event MessageInitiated(
        bytes32 indexed messageId,
        uint16 destinationChainId,
        address recipient,
        bytes message
    );

    /// @notice Emitted when a read request is initiated through the adapter
    event ReadRequestInitiated(
        bytes32 indexed requestId,
        uint16 srcChainId,
        uint16 dstChainId,
        address dstContract,
        bytes4 selector
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a transfer operation fails
    error TransferFailed();

    /**
     * @notice Transfer an asset to a destination chain
     * @param operationId Router-provided operation ID for tracking
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param recipient Address of the recipient on the destination chain
     * @param amount Amount of the asset to transfer
     * @param originator Address that initiated the transfer (for tracking/callbacks)
     * @param keeper Address that should receive any refunds
     * @param adapterParams Additional adapter-specific parameters
     * @dev Initiates a cross-chain asset transfer
     */
    function transferAsset(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable;

    /**
     * @notice Read state from a contract on a source chain
     * @param operationId Router-provided operation ID for tracking
     * @param srcChainId ID of the source chain
     * @param dstChainId ID of the destination chain
     * @param dstContract Address of the contract on the destination chain
     * @param selector Function selector to call
     * @param readParams Parameters for the function call
     * @param originator Address that initiated the read (for tracking/callbacks)
     * @param keeper Address that should receive any refunds
git sts     * @param adapterParams Additional adapter-specific parameters
     * @dev Initiates a cross-chain state read operation
     */
    function readState(
        bytes32 operationId,
        uint16 srcChainId,
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable;

    /**
     * @notice Send a general message to a destination chain
     * @param operationId Router-provided operation ID for tracking
     * @param destinationChainId ID of the destination chain
     * @param recipient Address of the recipient on the destination chain
     * @param message The message data to send
     * @param originator Address that initiated the message (for tracking/callbacks)
     * @param keeper Address that should receive any refunds
     * @param adapterParams Additional adapter-specific parameters
     * @dev Initiates a cross-chain messaging operation
     */
    function sendMessage(
        bytes32 operationId,
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        address keeper,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable;
}
