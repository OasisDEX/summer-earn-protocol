// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {CrossChainConfigManaged} from "@summerfi/chain-bridge/contracts/CrossChainConfigManaged.sol";
import {CrossChainReceiverBase} from "@summerfi/chain-bridge/base/CrossChainReceiverBase.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
import {ReceiptNotifier} from "../common/ReceiptNotifier.sol";
import {IFleetProxy} from "../../interfaces/IFleetProxy.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";

/**
 * @title CrossChainArk
 * @notice Ark contract for managing cross-chain deposits and withdrawals
 * @dev Implements strategy for depositing tokens to a satellite chain proxy and handling cross-chain messages.
 *      Supports cross-chain asset reception, state read responses, and inflight asset tracking.
 */
contract CrossChainArk is
    Ark,
    CrossChainConfigManaged,
    CrossChainReceiverBase,
    ICrossChainArk,
    ReceiptNotifier
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The satellite chain ID where the fleet proxy operates
    uint16 public immutable satelliteChainId;

    /// @notice Last known remote asset balance (from state read)
    uint256 public lastRemoteAssetBalance;

    /// @notice Amount of assets currently in-flight (being bridged)
    uint256 public inflightAssets;

    /// @notice The latest outgoing transfer ID
    bytes32 public latestOutgoingTransferId;

    /// @notice The latest incoming transfer ID
    bytes32 public latestIncomingTransferId;

    /// @notice Pending transfer params for the cross-chain transfer
    BridgeTypes.ExecuteTransferParams public pendingTransferParams;

    /// @notice Pending transfer options for the cross-chain transfer
    BridgeTypes.BridgeOptions public pendingTransferOptions;

    /// @notice Emitted when inflight is set for an outbound transfer
    event InflightSet(uint256 amount, bytes32 operationId);
    /// @notice Emitted when inflight is cleared following an ACK/state update
    event InflightCleared(bytes32 operationId, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // singleFlight modifier removed in favor of explicit assertions for clarity

    /**
     * @notice Constructor to set up the CrossChainArk
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _satelliteChainId ID of the satellite chain where the fleet proxy operates
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _crossChainRegistry,
        uint16 _satelliteChainId,
        ArkParams memory _params
    ) Ark(_params) CrossChainConfigManaged(_crossChainRegistry) {
        if (_satelliteChainId == 0) revert InvalidSatelliteChain();

        satelliteChainId = _satelliteChainId;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Force update the inflight assets amount (emergency governance function)
    /// @param amount Amount of assets to set as in-flight
    /// @dev This is an emergency function that allows governance to manually correct inflight asset tracking
    /// in case of bridge failures or accounting discrepancies
    function forceUpdateInflightAssets(uint256 amount) external onlyGovernor {
        inflightAssets = amount;
        emit InflightSet(amount, bytes32(0));
    }

    /*//////////////////////////////////////////////////////////////
                        PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     * @notice Returns the total assets managed by this Ark
     * @return assets The total balance of underlying assets held by this Ark
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets =
            config.asset.balanceOf(address(this)) +
            lastRemoteAssetBalance +
            inflightAssets;
    }

    /**
     * @notice Alias using hub/satellite terminology
     * @return The satellite proxy address
     */
    function getSatelliteProxy() external view returns (address) {
        return _getSatelliteProxy();
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(CrossChainReceiverBase) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(ICrossChainArk).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function _notifierBridgeRouter() internal view override returns (address) {
        return bridgeRouter();
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards the Ark by initiating a cross-chain transfer
     * @param amount Amount of tokens to transfer
     * @dev This function queues a cross-chain transfer to the target proxy using the registry
     */
    function _board(
        uint256 amount,
        bytes calldata executeTransferParams
    ) internal override {
        _validateCanBoardOrDisembark();
        address proxyAddress = _getSatelliteProxy();

        (
            BridgeTypes.ExecuteTransferParams memory params,
            BridgeTypes.BridgeOptions memory options
        ) = abi.decode(
                executeTransferParams,
                (BridgeTypes.ExecuteTransferParams, BridgeTypes.BridgeOptions)
            );

        if (amount == 0) revert InvalidAmount();
        if (amount != params.amount) revert InvalidAmount();
        if (params.asset == address(0)) revert InvalidAsset();
        if (params.asset != address(config.asset)) revert InvalidAsset();
        if (params.target != proxyAddress) revert InvalidRecipient();
        if (params.originator != address(this)) revert InvalidRequestor();
        if (params.destinationChainId != satelliteChainId)
            revert InvalidSatelliteChain();

        pendingTransferParams = params;
        pendingTransferOptions = options;
    }

    /// @notice Executes the pending cross-chain transfer to the satellite chain
    /// @dev This function initiates the actual bridge transfer after validation
    /// @dev Only callable by keeper role
    /// @dev Emits InflightSet and PendingTransferQueued events
    function executeTransferAssets() external payable onlyKeeper {
        _assertCanExecuteTransfer();
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());
        config.asset.approve(
            address(bridgeRouter),
            pendingTransferParams.amount
        );
        // Set inflight before initiating the transfer
        inflightAssets = pendingTransferParams.amount;
        bytes32 operationId = bridgeRouter.executeTransferAssets{
            value: msg.value
        }(pendingTransferParams, pendingTransferOptions);

        latestOutgoingTransferId = operationId;
        emit InflightSet(inflightAssets, operationId);
        emit PendingTransferQueued(
            pendingTransferParams,
            pendingTransferOptions
        );
        _resetPendingTransferParams();
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL KEEPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Cancels a queued pending transfer
    /// @dev Resets pending transfer params and options; callable by keeper
    function cancelPendingTransfer() external onlyKeeper {
        if (pendingTransferParams.asset == address(0))
            revert NoPendingTransferQueued();
        _resetPendingTransferParams();
    }

    /**
     * @notice Disembarks the Ark by withdrawing assets that are available on the contract
     * @param amount Amount of tokens to withdraw
     * @dev This function only validates that enough assets are available on this contract
     * The actual withdrawal from the satellite chain is processed by a keeper through
     * FleetProxy.withdrawAndTransfer() which transfers assets back to this contract
     */
    function _disembark(uint256 amount, bytes calldata) internal view override {
        _validateCanBoardOrDisembark();
        // Ensure we have enough assets on the contract
        uint256 availableAssets = config.asset.balanceOf(address(this));
        if (availableAssets < amount) {
            revert InsufficientAssets(amount, availableAssets);
        }

        // Note: The actual token transfer is handled by the parent Ark.disembark method
        // No cross-chain message is required as satellite chain withdrawals are keeper-managed
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN RECEIVER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that the caller is authorized (only bridge router)
     * @dev Implementation of abstract method from CrossChainReceiverBase
     */
    function _requireAuthorizedCaller() internal view override {
        if (msg.sender != bridgeRouter()) {
            revert Unauthorized();
        }
    }

    /**
     * @notice Returns the operation types supported by CrossChainArk
     * @return supportedTypes Array containing MESSAGE and TRANSFER_ASSET operation types
     */
    function _getSupportedOperationTypes()
        internal
        pure
        override
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        supportedTypes = new BridgeTypes.OperationType[](2);
        supportedTypes[0] = BridgeTypes.OperationType.MESSAGE;
        supportedTypes[1] = BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /**
     * @notice Handles MESSAGE operation type (balance updates from FleetProxy)
     * @param params Decoded message parameters
     */
    function _handleMessage(
        BridgeTypes.RelayedMessageParams memory params
    ) internal override {
        if (params.sourceChainId != satelliteChainId)
            revert InvalidSourceChain();
        if (params.originator != _getSatelliteProxy()) revert InvalidSender();

        // Decode the remote asset balance
        (uint256 newRemoteBalance, bytes32 latestReceivedTransferId) = abi
            .decode(params.message, (uint256, bytes32));
        if (latestReceivedTransferId != latestOutgoingTransferId) {
            // we skip updating the remote balance if the transfer id (received in FleetProxy) is not the latest
            // sent by this Ark
            emit InvalidTransferId(
                latestReceivedTransferId,
                latestOutgoingTransferId
            );
            return;
        }

        lastRemoteAssetBalance = newRemoteBalance;
        emit RemoteAssetBalanceUpdated(
            lastRemoteAssetBalance,
            params.operationId
        );

        // Reset inflight assets as the state read now reflects the current remote balance
        if (inflightAssets > 0) {
            uint256 previous = inflightAssets;
            inflightAssets = 0;
            emit InflightCleared(params.operationId, previous);
        }
    }

    /**
     * @notice Validates that the board or disembark can be performed
     * @dev This function validates that no inflight transfer exists and no pending transfer is queued
     */
    function _validateCanBoardOrDisembark() internal view {
        if (inflightAssets != 0) revert InFlight();
        if (pendingTransferParams.asset != address(0)) {
            revert PendingTransferAlreadyQueued();
        }
    }

    /**
     * @notice Handles TRANSFER_ASSET operation type (asset withdrawals from FleetProxy)
     * @param params Decoded transfer parameters
     * @dev Emits RemoteAssetBalanceUpdated and AssetsReceived events
     */
    function _handleTransferAsset(
        BridgeTypes.RelayedTransferParams memory params
    ) internal override {
        if (params.operationId == bytes32(0)) {
            emit MessageContentNotExpected();
        }
        if (params.sourceChainId != satelliteChainId)
            revert InvalidSourceChain();
        if (params.asset != address(config.asset)) revert InvalidAsset();
        if (params.originator != _getSatelliteProxy())
            revert InvalidRequestor();

        uint256 remoteBalance = abi.decode(params.message, (uint256));
        // Update the remote asset tracking

        lastRemoteAssetBalance = remoteBalance;
        emit RemoteAssetBalanceUpdated(
            lastRemoteAssetBalance,
            params.operationId
        );

        emit AssetsReceived(params.asset, params.amount, params.sourceChainId);

        // Track the latest incoming transfer id to ACK back to satellite
        latestIncomingTransferId = params.operationId;
    }

    /// @notice Notifies the satellite chain proxy that assets have been received on the hub
    /// @dev Keeper-triggered message to clear inflight on FleetProxy via ACK
    function notifySatelliteChain(
        BridgeTypes.BridgeOptions calldata options
    ) external payable onlyKeeper {
        if (latestIncomingTransferId == bytes32(0)) revert InvalidRequestor();
        _sendNotification(
            satelliteChainId,
            _getSatelliteProxy(),
            abi.encode(latestIncomingTransferId),
            options,
            msg.sender
        );
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when the sender is invalid
    error InvalidSender();
    /// @notice Error thrown when trying to start a new outbound while inflight > 0
    error InFlight();

    /**
     * @notice Ensures ready for executing a pending transfer: no inflight and has pending
     * @dev Used to gate executeTransferAssets
     */
    function _assertCanExecuteTransfer() internal view {
        if (inflightAssets != 0) revert InFlight();
        if (pendingTransferParams.asset == address(0)) {
            revert NoPendingTransferQueued();
        }
    }

    /**
     * @notice Gets the satellite proxy address from the registry
     * @return proxyAddress The satellite proxy address
     * @dev Reverts if no relationship exists for the satellite chain
     */
    function _getSatelliteProxy() internal view returns (address proxyAddress) {
        ICrossChainRegistry.CrossChainRelation
            memory relation = ICrossChainRegistry(crossChainRegistry())
                .getRelationshipByTarget(
                    address(this),
                    ICrossChainRegistry(crossChainRegistry())
                        .PEER_RELATIONSHIP(),
                    satelliteChainId
                );

        if (relation.targetContract == address(0)) {
            revert InvalidSatelliteChain();
        }

        return relation.targetContract;
    }

    /**
     * @notice Validates the board data
     * @dev This Ark does not require any validation for board data
     * @param data Additional data to validate (unused in this implementation)
     */
    function _validateBoardData(bytes calldata data) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev This Ark does not require any validation for disembark data
     * @param data Additional data to validate (unused in this implementation)
     */
    function _validateDisembarkData(bytes calldata data) internal override {}

    /**
     * @notice Returns the total withdrawable assets
     * @return The total balance of the underlying asset
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256)
    {
        return config.asset.balanceOf(address(this));
    }

    /**
     * @notice Resets the pending transfer params
     * @dev This function is used to reset the pending transfer params after the transfer has been executed
     */
    function _resetPendingTransferParams() internal {
        pendingTransferParams = BridgeTypes.ExecuteTransferParams({
            destinationChainId: 0,
            asset: address(0),
            amount: 0,
            target: address(0),
            originator: address(0),
            refundAddress: address(0),
            message: ""
        });
        pendingTransferOptions = BridgeTypes.BridgeOptions({
            specifiedAdapter: address(0),
            gasLimit: 0,
            calldataSize: 0,
            msgValue: 0,
            options: bytes("")
        });
    }

    /**
     * @notice Harvests rewards from the Ark
     * @dev This Ark does not implement harvesting as it's a cross-chain bridge
     * @return rewardTokens Empty array of reward tokens
     * @return rewardAmounts Empty array of reward amounts
     */
    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](0);
        rewardAmounts = new uint256[](0);
    }
}
