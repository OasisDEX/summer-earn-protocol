// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

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
        uint16 destinationChainId,
        address destinationContract,
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
     * @param params Parameters for the transfer
     * @param options Bridge options including adapter selection and parameters
     * @dev Initiates a cross-chain asset transfer
     */
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable;

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
}
