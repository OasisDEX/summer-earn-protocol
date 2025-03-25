// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {ISendAdapter} from "./ISendAdapter.sol";

/**
 * @title IBridgeAdapter
 * @notice Core interface for bridge adapters with shared functionality
 */
interface IBridgeAdapter is ISendAdapter {
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

    /// @notice Emitted when a relay or messaging operation fails
    event RelayFailed(bytes32 indexed transferId, bytes reason);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a call is made by an unauthorized address
    error Unauthorized();

    /// @notice Thrown when provided parameters are invalid
    error InvalidParams();

    /// @notice Thrown when a transfer operation fails
    error TransferFailed();

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when an asset is not supported for a specific chain
    error UnsupportedAsset();

    /// @notice Thrown when the operation is not supported by the adapter
    error OperationNotSupported();

    /// @notice Thrown when insufficient fee is provided for an operation
    error InsufficientFee(uint256 required, uint256 provided);

    /**
     * @notice Estimate the fee required for a cross-chain transfer
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.AdapterParams calldata adapterParams
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

    // Capability flags
    function supportsAssetTransfer() external view returns (bool);
    function supportsMessaging() external view returns (bool);
    function supportsStateRead() external view returns (bool);
}
