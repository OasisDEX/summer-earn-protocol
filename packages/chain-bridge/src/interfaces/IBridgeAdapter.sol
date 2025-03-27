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

    /// @notice Emitted when a transfer is received through the adapter
    event TransferReceived(
        bytes32 indexed transferId,
        address asset,
        uint256 amount,
        address recipient
    );

    /// @notice Emitted when a message is delivered through the adapter
    event MessageDelivered(
        bytes32 indexed messageId,
        address recipient,
        bool delivered
    );

    /// @notice Emitted when a read response is delivered through the adapter
    event ReadResponseDelivered(
        bytes32 indexed requestId,
        bytes response,
        bool delivered
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

    /// @notice Thrown when a chain is not supported
    error UnsupportedChain();

    /// @notice Thrown when an asset is not supported for a specific chain
    error UnsupportedAsset();

    /// @notice Thrown when the operation is not supported by the adapter
    error OperationNotSupported();

    /// @notice Thrown when insufficient fee is provided for an operation
    error InsufficientFee(uint256 required, uint256 provided);

    /**
     * @notice Estimate fees for a cross-chain operation
     * @param destinationChainId ID of the destination chain
     * @param asset Address of the asset to transfer (address(0) for non-asset operations)
     * @param amount Amount of the asset to transfer (0 for non-asset operations)
     * @param adapterParams Additional adapter-specific parameters
     * @param operationType Type of operation (0=MESSAGE, 1=READ_STATE, 2=TRANSFER_ASSET)
     * @return nativeFee Fee in the chain's native token
     * @return tokenFee Fee in the transferred token (if applicable)
     */
    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        BridgeTypes.AdapterParams calldata adapterParams,
        BridgeTypes.OperationType operationType
    ) external view returns (uint256 nativeFee, uint256 tokenFee);

    /**
     * @notice Get the status of a transfer
     */
    function getOperationStatus(
        bytes32 operationId
    ) external view returns (BridgeTypes.OperationStatus);

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
