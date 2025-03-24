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
     * @param destinationChainId Chain ID of the destination chain
     * @param asset Address of the asset to transfer
     * @param recipient Address of the recipient on the destination chain
     * @param amount Amount of the asset to transfer
     * @param adapterParams Additional adapter-specific parameters
     * @return transferId Unique ID for tracking the transfer
     */
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Read state from a contract on a source chain
     * @param sourceChainId Chain ID of the source chain
     * @param sourceContract Address of the contract on the source chain
     * @param selector Selector of the function to call on the source contract
     * @param readParams Parameters for the read operation
     * @param adapterParams Additional adapter-specific parameters
     * @return requestId Unique ID for tracking the read request
     */
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata readParams,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 requestId);

    /**
     * @notice Request an asset transfer from a remote chain
     * @param asset Address of the asset to transfer
     * @param amount Amount of the asset to transfer
     * @param sender Address of the sender on the source chain
     * @param sourceChainId Chain ID of the source chain
     * @param transferId Unique ID for tracking the transfer
     * @param extraData Additional data for the transfer
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
     * @param adapterParams Additional adapter-specific parameters
     * @return requestId Unique ID for tracking the composed request
     */
    function composeActions(
        uint16 destinationChainId,
        bytes[] calldata actions,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32 requestId);
}
