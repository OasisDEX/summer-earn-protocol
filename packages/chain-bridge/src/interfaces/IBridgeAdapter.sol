// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {ISendAdapter} from "./ISendAdapter.sol";
import {IReceiveAdapter} from "./IReceiveAdapter.sol";

/**
 * @title IBridgeAdapter
 * @notice Core interface for bridge adapters with shared functionality
 */
interface IBridgeAdapter is ISendAdapter, IReceiveAdapter {
    /**
     * @notice Estimate the fee required for a cross-chain transfer
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.AdapterOptions calldata adapterOptions
    ) external view returns (uint256 nativeFee, uint256 tokenFee);

    /**
     * @notice Get the status of a transfer
     */
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (BridgeTypes.TransferStatus);

    /**
     * @notice Get the list of supported chains
     */
    function getSupportedChains() external view returns (uint16[] memory);

    /**
     * @notice Get the list of supported assets for a chain
     */
    function getSupportedAssets(
        uint16 chainId
    ) external view returns (address[] memory);

    /**
     * @notice Check if an adapter supports a specific chain
     */
    function supportsChain(uint16 chainId) external view returns (bool);

    /**
     * @notice Check if an adapter supports a specific asset for a chain
     */
    function supportsAsset(
        uint16 chainId,
        address asset
    ) external view returns (bool);

    /**
     * @notice Get the type of an adapter
     */
    function getAdapterType() external view returns (uint8);
}
