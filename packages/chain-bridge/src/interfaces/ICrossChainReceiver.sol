// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface ICrossChainReceiver {
    /**
     * @notice Called when assets are received from another chain
     */
    function receiveAssets(
        address asset,
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external;

    /**
     * @notice Called when a message is received from another chain
     */
    function receiveMessage(
        bytes calldata message,
        address sender,
        uint16 sourceChainId,
        bytes32 messageId
    ) external;

    /**
     * @notice Called when a state read result is received from another chain
     */
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external;
}
