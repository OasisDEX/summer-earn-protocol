// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IBridgeRouter
 * @notice Interface for the BridgeRouter contract
 */
interface IBridgeRouter {
    /**
     * @notice Transfer an asset to a destination chain
     */
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    ) external payable returns (bytes32 transferId);

    /**
     * @notice Estimate the fee required for a cross-chain transfer
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options
    )
        external
        view
        returns (uint256 nativeFee, uint256 tokenFee, address selectedAdapter);

    /**
     * @notice Get the status of a transfer
     */
    function getTransferStatus(
        bytes32 transferId
    ) external view returns (BridgeTypes.TransferStatus);

    /**
     * @notice Check if an address is a registered adapter
     */
    function isValidAdapter(address adapter) external view returns (bool);

    /**
     * @notice Register a new bridge adapter
     */
    function registerAdapter(address adapter) external;

    /**
     * @notice Remove a bridge adapter
     */
    function removeAdapter(address adapter) external;

    /**
     * @notice Pause all bridge operations
     */
    function pause() external;

    /**
     * @notice Unpause bridge operations
     */
    function unpause() external;
}
