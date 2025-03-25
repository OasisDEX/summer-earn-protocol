// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ISendAdapter
 * @notice Interface for bridge adapters that can send messages and assets across chains
 * @dev This interface defines methods for initiating various cross-chain operations
 */
interface ISendAdapter {
    /**
     * @notice Transfer an asset to a destination chain
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param recipient Address of the recipient on the destination chain
     * @param amount Amount of the asset to transfer
     * @param originator Address that initiated the transfer (for refunds)
     * @param adapterParams Additional adapter-specific parameters
     * @return transferId Unique ID to track this transfer
     * @dev Initiates a cross-chain asset transfer
     */
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Read state from a contract on a source chain
     * @param sourceChainId ID of the source chain
     * @param sourceContract Address of the contract on the source chain
     * @param selector Function selector to call
     * @param readParams Parameters for the function call
     * @param originator Address that initiated the read (for refunds)
     * @param adapterParams Additional adapter-specific parameters
     * @return requestId Unique ID to track this read request
     * @dev Initiates a cross-chain state read operation
     */
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Send a general message to a destination chain
     * @param destinationChainId ID of the destination chain
     * @param recipient Address of the recipient on the destination chain
     * @param message The message data to send
     * @param originator Address that initiated the message (for refunds)
     * @param adapterParams Additional adapter-specific parameters
     * @return messageId Unique ID to track this message
     * @dev Initiates a cross-chain messaging operation
     */
    function sendMessage(
        uint16 destinationChainId,
        address recipient,
        bytes calldata message,
        address originator,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 messageId);
}
