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
     * @notice Estimate fees for a transfer operation using execution parameters
     * @param params Transfer parameters identical to execute methods
     * @param options Bridge options including adapter selection and parameters
     * @return nativeFee Fee in the chain's native token
     * @return tokenFee Fee in the transferred token (if applicable)
     */
    function estimateTransferAssets(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external view returns (uint256 nativeFee, uint256 tokenFee);
}
