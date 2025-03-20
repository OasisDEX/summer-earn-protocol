// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title IReceiveAdapter
 * @notice Interface for handling incoming cross-chain messages and transactions
 */
interface IReceiveAdapter {
    /**
     * @notice Handles incoming asset transfer requests from another chain
     */
    function receiveAssetTransfer(
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external;

    /**
     * @notice Handles incoming messages from another chain
     */
    function receiveMessage(
        bytes calldata message,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) external;

    /**
     * @notice Handles incoming state read results from another chain
     */
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;
}
