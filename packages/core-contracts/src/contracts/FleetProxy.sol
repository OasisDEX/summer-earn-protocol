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
import {CrossChainReceiverBase} from "./base/CrossChainReceiverBase.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
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
    IInflightAssetTracking,
    IFleetProxy,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /// @notice Relationship type constant for ARK-FLEET relationships
    bytes32 private constant ARK_FLEET_RELATIONSHIP =
        keccak256("ARK_FLEET_RELATIONSHIP");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetAddress;

    /// @notice Amount of withdrawal assets currently in-flight (being bridged back)
    uint256 public inflightWithdrawals;

    /// @notice The source chain ID where the fleet is deployed
    uint16 public immutable hubChainId;

    /// @notice The latest incoming transfer ID
    bytes32 public latestIncomingTransferId;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _fleetAddress Address of the Fleet contract this proxy covers
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _crossChainRegistry,
        address _fleetAddress,
        uint16 _sourceChainId
    )
        ProtocolAccessManaged(_accessManager)
        CrossChainConfigManaged(_crossChainRegistry)
    {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_crossChainRegistry == address(0)) revert InvalidRegistry();
        if (_fleetAddress == address(0)) revert InvalidFleetContract();

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
        return
            IFleetCommander(fleetAddress).totalAssets() + inflightWithdrawals;
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
    function forceUpdateInflightAssets(uint256 amount) external onlyGovernor {
        inflightWithdrawals = amount;
        emit InflightAssetsUpdated(amount);
    }

    /// @inheritdoc IInflightAssetTracking
    function updateInflightAssets(uint256 amount) external {
        // Only the bridge router should be able to call this
        if (msg.sender != address(bridgeRouter())) {
            revert Unauthorized();
        }

        inflightWithdrawals = amount;
        emit InflightAssetsUpdated(amount);
    }

    /// @notice Keeper function to withdraw and transfer assets
    /// @param amount The amount of assets to withdraw
    /// @param options The bridge options
    /// @dev This function is used to withdraw assets from the fleet contract and transfer them to the hub chain
    /// @dev This function is only callable by the keeper
    /// @dev We attach the remaining fleet balance to the message to be delivered to the hub chain
    function withdrawAndTransfer(
        uint amount,
        BridgeTypes.BridgeOptions calldata options
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        if (amount == 0) revert NoAssets();
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());

        // 1. Get the asset from fleet contract
        address asset = IERC4626(fleetAddress).asset();

        // 2. Withdraw from fleet contract
        IFleetCommander(fleetAddress).withdraw(
            amount,
            address(this),
            address(this)
        );
        uint256 fleetBalance = IFleetCommander(fleetAddress).balanceOf(
            address(this)
        );

        // 3. Verify we received the expected amount
        if (IERC20(asset).balanceOf(address(this)) < amount)
            revert WithdrawalFailed();

        // 4. Track inflight withdrawals before bridging
        inflightWithdrawals += amount;
        emit InflightAssetsUpdated(inflightWithdrawals);

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
                message: abi.encode(fleetBalance),
                refundAddress: address(this)
            });

        // 7. Execute the cross-chain transfer back to the Ark on the hub chain
        bridgeRouter.executeTransferAssets{value: msg.value}(params, options);

        emit AssetsWithdrawnAndTransferred(
            params.amount,
            params.asset,
            hubChainId
        );
    }

    // todo: revise security wise
    /**
     * @notice Notifies the source chain that assets have been received
     */
    function notifySourceChain(
        BridgeTypes.BridgeOptions calldata options
    ) external payable whenNotPaused nonReentrant onlyKeeper {
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());
        uint256 fleetBalance = IFleetCommander(fleetAddress).balanceOf(
            address(this)
        );
        BridgeTypes.ExecuteSendMessageParams memory params = BridgeTypes
            .ExecuteSendMessageParams({
                originator: address(this),
                destinationChainId: hubChainId,
                target: _getSourceChainArk(hubChainId),
                message: abi.encode(fleetBalance, latestIncomingTransferId),
                refundAddress: address(this)
            });
        bridgeRouter.executeSendMessage(params, options);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(CrossChainReceiverBase, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainReceiver).interfaceId ||
            interfaceId == type(IInflightAssetTracking).interfaceId ||
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
                ARK_FLEET_RELATIONSHIP
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
                ARK_FLEET_RELATIONSHIP
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
                            ARK_FLEET_RELATIONSHIP
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
}
