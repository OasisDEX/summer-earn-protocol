// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IMessageAdapter
 * @notice Interface for bridge adapters that can send messages and read state across chains
 * @dev This interface defines methods for messaging and read operations only
 */
interface IMessageAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

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
        uint16 destinationChainId,
        address destinationContract,
        bytes4 selector
    );

    /// @notice Emitted when a read operation is not found through the adapter
    event ReadOperationNotFound(bytes32 indexed guid, string reason);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a read operation fails
    error ReadFailed();

    /*//////////////////////////////////////////////////////////////
                           CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Read state from a contract on a source chain
     * @param operationId Router-provided operation ID for tracking
     * @param params Parameters for the read state operation
     * @param options Bridge options including adapter selection and parameters
     * @dev Initiates a cross-chain state read operation
     */
    function readState(
        bytes32 operationId,
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable;

    /**
     * @notice Send a general message to a destination chain
     * @param operationId Router-provided operation ID for tracking
     * @param params Parameters for the send message operation
     * @param options Bridge options including adapter selection and parameters
     * @dev Initiates a cross-chain messaging operation
     */
    function sendMessage(
        bytes32 operationId,
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable;

    /**
     * @notice Check if the adapter supports a specific message operation type to a destination
     * @param destinationChainId ID of the destination chain
     * @param operationType Type of operation (MESSAGE or READ_STATE)
     * @return Whether the operation is supported
     */
    function supportsMessageOperation(
        uint16 destinationChainId,
        BridgeTypes.OperationType operationType
    ) external view returns (bool);
}
