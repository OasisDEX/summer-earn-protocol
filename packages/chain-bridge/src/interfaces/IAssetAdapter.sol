// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title IAssetAdapter
 * @notice Interface for bridge adapters that can transfer assets across chains
 * @dev This interface defines methods for asset transfers only
 */
interface IAssetAdapter {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a transfer is initiated through the adapter
    event TransferInitiated(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when a transfer is received through the adapter
    event TransferReceived(
        bytes32 indexed transferId,
        address asset,
        uint256 amount,
        address recipient
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a transfer operation fails
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                           CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Transfer an asset to a destination chain
     * @param operationId Router-provided operation ID for tracking
     * @param params Parameters for the transfer
     * @param options Bridge options including adapter selection and parameters
     * @dev Initiates a cross-chain asset transfer
     */
    function transferAsset(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external payable;

    /**
     * @notice Check if the adapter supports asset transfers to a specific chain
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer
     * @return Whether asset transfers are supported
     */
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address asset
    ) external view returns (bool);
}
