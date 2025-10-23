// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {CrossChainConfigManaged} from "@summerfi/chain-bridge/contracts/CrossChainConfigManaged.sol";
import {CrossChainReceiverBase} from "@summerfi/chain-bridge/base/CrossChainReceiverBase.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
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
    ICrossChainArk
{
    /// @notice Relationship type constant for ARK-FLEET relationships
    bytes32 private constant ARK_FLEET_RELATIONSHIP =
        keccak256("ARK_FLEET_RELATIONSHIP");
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

    /// @notice Pending transfer params for the cross-chain transfer
    BridgeTypes.ExecuteTransferParams public pendingTransferParams;

    /// @notice Pending transfer options for the cross-chain transfer
    BridgeTypes.BridgeOptions public pendingTransferOptions;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the CrossChainArk
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _satelliteChainId ID of the satellite chain where the fleet proxy operates
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _bridgeRouter,
        address _crossChainRegistry,
        uint16 _satelliteChainId,
        ArkParams memory _params
    ) Ark(_params) CrossChainConfigManaged(_crossChainRegistry) {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
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
        emit InflightAssetsUpdated(amount);
    }

    /// @notice Updates the inflight assets amount when a bridge operation is executed
    /// @param amount Amount of assets that are now in-flight
    function updateInflightAssets(uint256 amount) external {
        // Only the bridge router should be able to call this
        if (msg.sender != bridgeRouter()) {
            revert Unauthorized();
        }
        inflightAssets = amount;
        emit InflightAssetsUpdated(amount);
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
     * @notice Gets the target proxy address from the registry
     * @return The target proxy address
     * @dev Reverts if no relationship exists for the satellite chain
     */
    function getTargetProxy() external view returns (address) {
        return _getTargetProxy();
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(CrossChainReceiverBase, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(ICrossChainArk).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
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
        if (pendingTransferParams.asset != address(0)) {
            revert PendingTransferAlreadyQueued();
        }
        address proxyAddress = _getTargetProxy();

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

    function executeTransferAssets() external payable onlyKeeper {
        if (pendingTransferParams.asset == address(0))
            revert NoPendingTransferQueued();
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());
        config.asset.approve(
            address(bridgeRouter),
            pendingTransferParams.amount
        );
        bytes32 operationId = bridgeRouter.executeTransferAssets{
            value: msg.value
        }(pendingTransferParams, pendingTransferOptions);

        latestOutgoingTransferId = operationId;
        emit PendingTransferQueued(
            pendingTransferParams,
            pendingTransferOptions
        );
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
        if (params.originator != _getTargetProxy()) revert InvalidSender();

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
            inflightAssets = 0;
            emit InflightAssetsUpdated(0);
        }
    }

    /**
     * @notice Handles TRANSFER_ASSET operation type (asset withdrawals from FleetProxy)
     * @param params Decoded transfer parameters
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
        if (params.originator != _getTargetProxy()) revert InvalidRequestor();

        uint256 remoteBalance = abi.decode(params.message, (uint256));
        // Update the remote asset tracking

        lastRemoteAssetBalance = remoteBalance;

        emit AssetsReceived(params.asset, params.amount, params.sourceChainId);
    }

    /*//////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    error InvalidSender();

    /**
     * @notice Gets the target proxy address from the registry
     * @return proxyAddress The target proxy address
     * @dev Reverts if no relationship exists for the satellite chain
     */
    function _getTargetProxy() internal view returns (address proxyAddress) {
        ICrossChainRegistry.CrossChainRelation
            memory relation = ICrossChainRegistry(crossChainRegistry())
                .getRelationshipByTarget(
                    address(this),
                    ARK_FLEET_RELATIONSHIP,
                    satelliteChainId
                );
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
