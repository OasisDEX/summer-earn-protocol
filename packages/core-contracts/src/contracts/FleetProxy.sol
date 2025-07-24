// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {CrossChainConfigManaged} from "@summerfi/chain-bridge/contracts/CrossChainConfigManaged.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
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
    ICrossChainAssetReceiver,
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
    function withdrawAndTransfer(
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata options
    ) external whenNotPaused nonReentrant onlyKeeper {
        IBridgeRouter bridgeRouter = IBridgeRouter(bridgeRouter());

        // 1. Get the asset from fleet contract
        address asset = IERC4626(fleetAddress).asset();
        if (params.amount == 0) revert NoAssets();

        if (params.asset != asset) revert InvalidAsset();
        if (params.originator != address(this)) revert InvalidRequestor();
        if (params.destinationChainId != hubChainId)
            revert InvalidSatelliteChain();
        if (params.target != _getSourceChainArk(params.destinationChainId))
            revert InvalidRecipient();

        // 2. Withdraw from fleet contract
        IFleetCommander(fleetAddress).withdraw(
            params.amount,
            address(this),
            address(this)
        );

        // 3. Verify we received the expected amount
        if (IERC20(asset).balanceOf(address(this)) < params.amount)
            revert WithdrawalFailed();

        // 4. Track inflight withdrawals before bridging
        inflightWithdrawals += params.amount;
        emit InflightAssetsUpdated(inflightWithdrawals);

        // 5. Approve the bridge router to transfer the assets
        IERC20(asset).forceApprove(address(bridgeRouter), params.amount);

        // 6. Queue the cross-chain transfer back to the Ark on the hub chain
        bridgeRouter.executeTransferAssets(params, options);

        emit AssetsWithdrawnAndTransferred(
            params.amount,
            params.asset,
            hubChainId
        );
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-CHAIN RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainAssetReceiver
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message,
        uint16 _hubChainId
    ) external whenNotPaused nonReentrant {
        BridgeTypes.DeliverPayload memory dp = abi.decode(
            message,
            (BridgeTypes.DeliverPayload)
        );

        if (dp.operationId == bytes32(0)) {
            emit MessageContentNotExpected();
        }

        // Only a registered adapter can call this function
        if (!IBridgeRouter(bridgeRouter()).isValidAdapter(msg.sender)) {
            revert CallerNotRegisteredAdapter();
        }

        // Validate the relationship using registry
        if (!_isValidSourceChain(_hubChainId)) {
            revert InvalidSourceChain();
        }

        // Check if the asset matches the fleet's asset
        if (asset != IERC4626(fleetAddress).asset()) {
            revert InvalidAsset();
        }

        if (amount == 0) {
            revert NoAssets();
        }

        _handleReceiveAssets(asset, amount, _hubChainId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(ICrossChainAssetReceiver, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(IInflightAssetTracking).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
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
