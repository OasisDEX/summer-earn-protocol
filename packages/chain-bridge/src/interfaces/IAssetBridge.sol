// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAssetBridge
 * @notice Interface implemented by contracts that want to receive bridged assets
 */
interface IAssetBridge {
    /**
     * @notice Called by the bridge adapter to deliver received assets
     * @param amount Amount of the asset received
     * @param sender Address that sent the assets on the source chain
     * @param sourceChainId ID of the source chain
     * @param transferId Unique ID of the transfer
     */
    function receiveCrossChain(
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId
    ) external;
}
