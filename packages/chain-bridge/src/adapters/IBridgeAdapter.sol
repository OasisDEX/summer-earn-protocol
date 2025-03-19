// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBridgeAdapter
 * @notice Interface for all bridge adapters
 */
interface IBridgeAdapter {
    /**
     * @notice Transfer an asset to a destination chain
     */
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Estimate the fee required for a cross-chain transfer
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
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
}
