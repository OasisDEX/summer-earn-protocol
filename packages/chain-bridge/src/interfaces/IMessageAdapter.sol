// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IMessageAdapter
 * @notice Interface for bridge adapters that can send messages across chains
 * @dev READ_STATE is currently not implemented by the protocol; related APIs removed
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

    /*//////////////////////////////////////////////////////////////
                           CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
     * @notice Check if the adapter supports MESSAGE to a destination
     */
    function supportsMessageOperation(
        uint16 destinationChainId,
        BridgeTypes.OperationType operationType
    ) external view returns (bool);
}
