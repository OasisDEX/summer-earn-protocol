// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {CrossChainConfigManaged} from "@summerfi/chain-bridge/contracts/CrossChainConfigManaged.sol";
import {CrossChainReceiverBase} from "@summerfi/chain-bridge/base/CrossChainReceiverBase.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IFleetProxy} from "../interfaces/IFleetProxy.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title FleetProxy
 * @notice Proxy contract for managing cross-chain Fleet operations
 * @dev Implements cross-chain asset reception and management for Fleet contracts
 */
contract FleetProxy is
    ProtocolAccessManaged,
    CrossChainConfigManaged,
    CrossChainReceiverBase,
    IFleetProxy,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /// @notice Relationship type constant for ARK-PEER relationships
    bytes32 private constant ARK_PEER_RELATIONSHIP =
        keccak256("PEER_RELATIONSHIP");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetAddress;

    /// @notice Amount of withdrawal assets currently in-flight (being bridged back)
    uint256 public inflightWithdrawals;

    /// @notice The hub/source chain ID where the Ark is deployed
    uint16 public immutable hubChainId;

    /// @notice The latest incoming transfer ID
    bytes32 public latestIncomingTransferId;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the FleetProxy
     * @param _accessManager Address of the access manager
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _fleetAddress Address of the Fleet contract this proxy covers
     * @param _sourceChainId The hub/source chain ID where the Ark is deployed
     */
    constructor(
        address _accessManager,
        address _crossChainRegistry,
        address _fleetAddress,
        uint16 _sourceChainId
    )
        ProtocolAccessManaged(_accessManager)
        CrossChainConfigManaged(_crossChainRegistry)
    {
        if (_crossChainRegistry == address(0)) revert InvalidRegistry();
        if (_fleetAddress == address(0)) revert InvalidFleetContract();
        if (_sourceChainId == 0) revert InvalidSourceChain();

        fleetAddress = _fleetAddress;
        hubChainId = _sourceChainId;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IFleetProxy
    function getBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc IFleetProxy
    function totalAssets() external view returns (uint256) {
        // Assets owned by this proxy are represented by:
        // - Shares held in the FleetCommander converted to assets
        // - Any local balance of the main asset held by this proxy
        // - Inflight withdrawals currently being bridged back
        address asset = IERC4626(fleetAddress).asset();
        uint256 shares = IFleetCommander(fleetAddress).balanceOf(address(this));
        uint256 assetsInFleet = IERC4626(fleetAddress).convertToAssets(shares);
        uint256 localBalance = IERC20(asset).balanceOf(address(this));
        return assetsInFleet + localBalance + inflightWithdrawals;
    }

    /// @inheritdoc IFleetProxy
    function pause() external onlyGuardian {
        _pause();
    }

    /// @inheritdoc IFleetProxy
    function unpause() external onlyGovernor {
        _unpause();
    }

    /// @notice Force update the inflight withdrawals amount (emergency governance function)
    /// @param amount Amount of withdrawal assets to set as in-flight
    /// @dev This is an emergency function that allows governance to manually correct inflight withdrawal tracking
    /// in case of bridge failures or accounting discrepancies
    /// @dev Emits InflightCleared if amount is 0, otherwise emits InflightSet
    function forceUpdateInflightAssets(uint256 amount) external onlyGovernor {
        uint256 previous = inflightWithdrawals;
        inflightWithdrawals = amount;
        if (amount == 0) {
            emit InflightCleared(bytes32(0), previous);
        } else {
            emit InflightSet(amount, bytes32(0));
        }
    }

    /// @notice SuperKeeper ACK to clear inflight withdrawals once hub receipt is verified off-chain
    /// @param operationId The outbound transfer operation ID being acknowledged (for audit/logging)
    /// @dev Emits InflightCleared event
    function acknowledgeHubReceipt(
        bytes32 operationId
    ) external whenNotPaused nonReentrant onlySuperKeeper {
        uint256 previous = inflightWithdrawals;
        if (previous == 0) revert InvalidOperation();
        inflightWithdrawals = 0;
        emit InflightCleared(operationId, previous);
    }

    /// @notice Emitted when inflight withdrawals are set locally
    event InflightSet(uint256 amount, bytes32 operationId);
    /// @notice Emitted when inflight withdrawals are cleared
    event InflightCleared(bytes32 operationId, uint256 amount);

    /// @notice Keeper function to withdraw and transfer assets
    /// @param amount The amount of assets to withdraw
    /// @param options The bridge options
    /// @dev This function is used to withdraw assets from the fleet contract and transfer them to the hub chain
    /// @dev This function is callable by any address with the KEEPER_ROLE
    /// @dev We attach the remaining fleet balance to the message for balance updates
    /// @dev Emits InflightSet and AssetsWithdrawnAndTransferred events
    function withdrawAndTransfer(
        uint amount,
        BridgeTypes.BridgeOptions calldata options
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        _assertCanWithdraw(amount);
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());

        // 1. Get the asset from fleet contract
        address asset = IERC4626(fleetAddress).asset();

        // 2. Withdraw from fleet contract
        IFleetCommander(fleetAddress).withdraw(
            amount,
            address(this),
            address(this)
        );
        uint256 fleetShares = IFleetCommander(fleetAddress).balanceOf(
            address(this)
        );
        uint256 fleetAssets = IFleetCommander(fleetAddress).convertToAssets(
            fleetShares
        );

        // 3. Verify we have sufficient balance to continue
        if (IERC20(asset).balanceOf(address(this)) < amount)
            revert WithdrawalFailed();

        // 4. Track inflight withdrawals before bridging (single-flight semantics)
        inflightWithdrawals = amount;

        // 5. Approve the bridge router to transfer the assets
        IERC20(asset).forceApprove(address(bridgeRouter), amount);

        // 6. Prepare the transfer parameters
        BridgeTypes.ExecuteTransferParams memory params = BridgeTypes
            .ExecuteTransferParams({
                originator: address(this),
                destinationChainId: hubChainId,
                target: _getSourceChainArk(hubChainId),
                asset: asset,
                amount: amount,
                message: abi.encode(fleetAssets),
                refundAddress: msg.sender
            });

        // 7. Execute the cross-chain transfer back to the Ark on the hub chain
        bytes32 opId = bridgeRouter.executeTransferAssets{value: msg.value}(
            params,
            options
        );

        emit InflightSet(inflightWithdrawals, opId);

        emit AssetsWithdrawnAndTransferred(
            params.amount,
            params.asset,
            hubChainId
        );
    }

    /**
     * @notice Notifies the source chain that assets have been received
     */
    function notifySourceChain(
        BridgeTypes.BridgeOptions calldata options
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());
        // Security: ensure the ARK relationship is currently valid in the registry
        if (!_isValidSourceChain(hubChainId)) revert InvalidSourceChain();
        // Security: include replay guard context - require we have a non-zero last transfer id
        if (latestIncomingTransferId == bytes32(0)) revert InvalidRequestor();
        uint256 fleetShares = IFleetCommander(fleetAddress).balanceOf(
            address(this)
        );
        uint256 fleetAssets = IFleetCommander(fleetAddress).convertToAssets(
            fleetShares
        );
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: address(this),
                destinationChainId: hubChainId,
                target: _getSourceChainArk(hubChainId),
                message: abi.encode(fleetAssets, latestIncomingTransferId),
                refundAddress: msg.sender
            });
        bridgeRouter.executeSendMessage{value: msg.value}(params, options);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(CrossChainReceiverBase, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        CROSS-CHAIN RECEIVER OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates that the caller is authorized (bridge router via registered adapter)
     * @dev Implementation of abstract method from CrossChainReceiverBase
     */
    function _requireAuthorizedCaller() internal view override {
        if (msg.sender != address(bridgeRouter())) {
            revert Unauthorized();
        }
    }

    /**
     * @notice Returns the operation types supported by FleetProxy
     * @return supportedTypes Array containing only TRANSFER_ASSET operation type
     */
    function _getSupportedOperationTypes()
        internal
        pure
        override
        returns (BridgeTypes.OperationType[] memory supportedTypes)
    {
        supportedTypes = new BridgeTypes.OperationType[](1);
        supportedTypes[0] = BridgeTypes.OperationType.TRANSFER_ASSET;
    }

    /**
     * @notice Handles TRANSFER_ASSET operation type (asset deposits from CrossChainArk)
     * @param params Decoded transfer parameters
     */
    function _handleTransferAsset(
        BridgeTypes.RelayedTransferParams memory params
    ) internal override whenNotPaused {
        if (params.operationId == bytes32(0)) {
            emit MessageContentNotExpected();
        }

        // Validate the relationship using registry
        if (!_isValidSourceChain(params.sourceChainId)) {
            revert InvalidSourceChain();
        }

        // Check if the asset matches the fleet's asset
        if (params.asset != IERC4626(fleetAddress).asset()) {
            revert InvalidAsset();
        }

        if (params.amount == 0) {
            revert NoAssets();
        }
        if (params.originator != _getSourceChainArk(params.sourceChainId)) {
            revert InvalidRequestor();
        }
        _handleReceiveAssets(params.asset, params.amount, params.sourceChainId);
        // Note: Inflight withdrawals are cleared via acknowledgeHubReceipt (SuperKeeper)
        // or forceUpdateInflightAssets (Governor) after bridge completion
        latestIncomingTransferId = params.operationId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the source chain ark address from the registry
     * @param _hubChainId The chain ID where the ark is deployed
     * @return arkAddress The source chain ark address
     * @dev Reverts if no valid relationship exists for the source chain
     */
    function _getSourceChainArk(
        uint16 _hubChainId
    ) internal view returns (address arkAddress) {
        return
            ICrossChainRegistry(crossChainRegistry()).getSourceForTarget(
                _hubChainId,
                ICrossChainRegistry(crossChainRegistry()).currentChainId(),
                address(this),
                ARK_PEER_RELATIONSHIP
            );
    }

    /**
     * @notice Validates if the source chain is valid for this proxy
     * @param _hubChainId The chain ID to validate
     * @return isValid True if the source chain is valid
     */
    function _isValidSourceChain(
        uint16 _hubChainId
    ) internal view returns (bool isValid) {
        try
            ICrossChainRegistry(crossChainRegistry()).getSourceForTarget(
                _hubChainId,
                ICrossChainRegistry(crossChainRegistry()).currentChainId(),
                address(this),
                ARK_PEER_RELATIONSHIP
            )
        returns (address ark) {
            if (ark != address(0)) {
                try
                    ICrossChainRegistry(crossChainRegistry())
                        .isValidCrossChainPair(
                            ark,
                            address(this),
                            hubChainId,
                            ICrossChainRegistry(crossChainRegistry())
                                .currentChainId(),
                            ARK_PEER_RELATIONSHIP
                        )
                returns (bool valid) {
                    return valid;
                } catch {
                    return false;
                }
            }
            return false;
        } catch {
            return false;
        }
    }

    /**
     * @notice Handles receiving assets from a cross-chain transfer
     * @param asset The asset address
     * @param amount The amount received
     * @param _hubChainId The source chain ID
     * @dev Emits ProxyDeposit event
     */
    function _handleReceiveAssets(
        address asset,
        uint256 amount,
        uint16 _hubChainId
    ) internal {
        // Approve the fleet contract to take the assets
        IERC20(asset).forceApprove(fleetAddress, amount);

        // Deposit the assets into the fleet contract
        IFleetCommander(fleetAddress).deposit(amount, address(this));

        // Emit an event for tracking
        emit ProxyDeposit(fleetAddress, asset, amount, _hubChainId);
    }

    /**
     * @notice Validates preconditions before withdrawing from fleet
     * @param amount The amount requested to withdraw
     */
    function _assertCanWithdraw(uint256 amount) internal view {
        if (amount == 0) revert NoAssets();
        if (inflightWithdrawals != 0) revert InFlight();
    }

    /// @notice Custom error for single-flight gating
    error InFlight();
}
