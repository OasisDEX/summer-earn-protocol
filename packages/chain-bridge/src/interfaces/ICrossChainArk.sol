// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IInflightAssetTracking} from "./IInflightAssetTracking.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ICrossChainArk
 * @notice Interface for the CrossChainArk contract which manages cross-chain assets
 * @dev Extends IInflightAssetTracking for consistent inflight asset management
 */
interface ICrossChainArk is IInflightAssetTracking {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the provided satellite chain ID is zero.
    error InvalidSatelliteChain();

    /// @notice Thrown when a message ID is invalid.
    error InvalidMessageId();

    /// @notice Thrown when a request ID is invalid.
    error InvalidRequestId();

    /// @notice Thrown when the source chain ID is invalid.
    error InvalidSourceChain();

    /// @notice Thrown when the recipient address is invalid.
    error InvalidRecipient();

    /// @notice Thrown when the requestor address is invalid.
    error InvalidRequestor();

    /// @notice Thrown when receiveOperation(BridgeTypes.OperationType.TRANSFER_ASSET,abi.encode( is called (not supported for this Ark).
    error ReceiveMessageWithAssetsNotSupported();

    /// @notice Thrown when there are insufficient assets on the contract to perform the withdrawal.
    error InsufficientAssets(uint256 requestedAmount, uint256 availableAmount);

    /// @notice Thrown when the provided asset address is invalid.
    error InvalidAsset();

    /// @notice Thrown when the provided amount is invalid.
    error InvalidAmount();

    /// @notice Thrown when the provided bridge router address is invalid.
    error InvalidBridgeRouter();

    /// @notice Thrown when the provided cross chain registry address is invalid.
    error InvalidCrossChainRegistry();

    /// @notice Thrown when there are no pending transfer params.
    error NoPendingTransferQueued();

    /// @notice Thrown when there are pending transfer params already queued.
    error PendingTransferAlreadyQueued();

    /// @notice Emitted when a message is not expected
    event MessageContentNotExpected();

    /// @notice Emitted when a pending transfer is queued
    event PendingTransferQueued(
        BridgeTypes.ExecuteTransferParams params,
        BridgeTypes.BridgeOptions options
    );

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the remote asset balance is updated via state read
    event RemoteAssetBalanceUpdated(uint256 newBalance, bytes32 requestId);

    /// @notice Emitted when assets are received from another chain
    event AssetsReceived(
        address indexed token,
        uint256 amount,
        uint16 sourceChainId
    );

    /// @notice Emitted when a remote asset balance update is requested
    event RemoteAssetBalanceUpdateRequested(
        bytes32 indexed queueId,
        uint16 targetChainId,
        address targetProxy
    );

    /// @notice Emitted when a transfer ID is invalid.
    event InvalidTransferId(
        bytes32 latestTransferReceivedInFleetProxy,
        bytes32 latestOutgoingTransferId
    );
}
