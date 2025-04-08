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
     * @param sourceChainId The chain id
     * @param message The message content
     */
    function receiveMessage(
        uint16 sourceChainId,
        bytes calldata message
    ) external;

    /**
     * @notice Receives a cross-chain message along with transferred assets
     * @param asset The address of the transferred asset
     * @param amount The amount of the asset transferred
     * @param message The message content
     */
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message
    ) external;

    /**
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @return True if the contract implements ICrossChainReceiver
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
