// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title ICrossChainReceiver
 * @notice Interface for contracts that receive cross-chain messages and read results
 * @dev Implemented by CrossChainArk and similar contracts that need to receive cross-chain data
 */
interface ICrossChainReceiver {
    /**
     * @notice Receives state read results from another chain
     * @param resultData The data returned from the cross-chain read
     * @param requestor The address that initiated the request (usually this contract)
     * @param sourceChainId The chain ID where the data was read from
     * @param requestId The unique ID of the original request
     */
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;

    /**
     * @notice Receives a general cross-chain message
     * @param message The message content
     * @param recipient The intended recipient of the message
     * @param sourceChainId The chain ID where the message originated
     * @param messageId The unique ID of the message
     */
    function receiveMessage(
        bytes calldata message,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) external;

    /**
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @return True if the contract implements ICrossChainReceiver
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
