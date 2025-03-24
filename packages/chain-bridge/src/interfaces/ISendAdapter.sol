// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ISendAdapter
 * @notice Interface for outbound cross-chain transactions
 */
interface ISendAdapter {
    /**
     * @notice Transfer an asset to a destination chain
     */
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        BridgeTypes.AdapterOptions calldata adapterOptions
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Read state from a contract on a source chain
     */
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.AdapterOptions calldata adapterOptions
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Request an asset transfer from a remote chain
     */
    function requestAssetTransfer(
        address asset,
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external payable;

    /**
     * @notice Compose multiple cross-chain actions into a single transaction
     * @param destinationChainId Chain ID where actions will be executed
     * @param actions Array of encoded action data to execute sequentially
     * @param adapterOptions Additional adapter-specific parameters
     * @return requestId Unique ID for tracking the composed request
     */
    function composeActions(
        uint16 destinationChainId,
        bytes[] calldata actions,
        BridgeTypes.AdapterOptions calldata adapterOptions
    ) external payable returns (bytes32 requestId);
}
