// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {CrossChainConfigManaged} from "@summerfi/chain-bridge/contracts/CrossChainConfigManaged.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {ICrossChainRegistry} from "@summerfi/chain-bridge/interfaces/ICrossChainRegistry.sol";
import {IFleetProxy} from "../interfaces/IFleetProxy.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";

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
    bytes32 private constant ARK_FLEET_RELATIONSHIP = keccak256("ARK_FLEET");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetContract;

    /// @notice Amount of withdrawal assets currently in-flight (being bridged back)
    uint256 public inflightWithdrawals;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param _accessManager Address of the access manager
     * @param _crossChainConfigManager Address of the CrossChainConfigManager contract
     * @param _fleetContract Address of the Fleet contract this proxy covers
     */
    constructor(
        address _accessManager,
        address _crossChainConfigManager,
        address _fleetContract
    )
        ProtocolAccessManaged(_accessManager)
        CrossChainConfigManaged(_crossChainConfigManager)
    {
        if (_fleetContract == address(0)) revert InvalidFleetContract();
        fleetContract = _fleetContract;
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
            IFleetCommander(fleetContract).totalAssets() + inflightWithdrawals;
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
        // Only the bridge queue or router should be able to call this
        if (msg.sender != bridgeQueue() && msg.sender != bridgeRouter()) {
            revert Unauthorized();
        }

        inflightWithdrawals = amount;
        emit InflightAssetsUpdated(amount);
    }

    /// @notice Keeper function to withdraw and transfer assets
    function withdrawAndTransfer(
        uint256 amount,
        uint16 sourceChainId
    ) external whenNotPaused nonReentrant onlyKeeper {
        if (amount == 0) revert NoAssets();

        // 1. Get the asset from fleet contract
        address asset = IERC4626(fleetContract).asset();

        // 2. Withdraw from fleet contract
        IFleetCommander(fleetContract).withdraw(
            amount,
            address(this),
            address(this)
        );

        // 3. Verify we received the expected amount
        if (IERC20(asset).balanceOf(address(this)) < amount)
            revert WithdrawalFailed();

        // 4. Track inflight withdrawals before bridging
        inflightWithdrawals += amount;
        emit InflightAssetsUpdated(inflightWithdrawals);

        // 5. Approve the bridge queue to transfer the assets
        IERC20(asset).forceApprove(bridgeQueue(), amount);

        // 6. Get source chain ark address from registry - reverts if not found
        address arkAddress = _getSourceChainArk(sourceChainId);

        // 7. Use BridgeQueue to queue a transfer of assets back to source chain's CrossChainArk
        IBridgeQueue(bridgeQueue()).queueTransferAssets(
            sourceChainId,
            asset,
            amount,
            arkAddress
        );

        emit AssetsWithdrawnAndTransferred(amount, asset, sourceChainId);
    }

    /*//////////////////////////////////////////////////////////////
                    CROSS-CHAIN RECEIVER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ICrossChainAssetReceiver
    function receiveMessageWithAssets(
        address asset,
        uint256 amount,
        bytes calldata message,
        uint16 sourceChainId
    ) external whenNotPaused nonReentrant {
        if (message.length == 0) {
            emit MessageContentNotExpected();
        }

        // Only a registered adapter can call this function
        if (!IBridgeRouter(bridgeRouter()).isValidAdapter(msg.sender)) {
            revert CallerNotRegisteredAdapter();
        }

        // Validate the relationship using registry
        if (!_isValidSourceChain(sourceChainId)) {
            revert InvalidSourceChain();
        }

        // Check if the asset matches the fleet's asset
        if (asset != IERC4626(fleetContract).asset()) {
            revert InvalidAsset();
        }

        if (amount == 0) {
            revert NoAssets();
        }

        _handleReceiveAssets(asset, amount, sourceChainId);
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
     * @param sourceChainId The chain ID where the ark is deployed
     * @return arkAddress The source chain ark address
     * @dev Reverts if no valid relationship exists for the source chain
     */
    function _getSourceChainArk(
        uint16 sourceChainId
    ) internal view returns (address arkAddress) {
        return
            ICrossChainRegistry(crossChainRegistry()).getSourceForTarget(
                sourceChainId,
                ICrossChainRegistry(crossChainRegistry()).currentChainId(),
                address(this),
                ARK_FLEET_RELATIONSHIP
            );
    }

    /**
     * @notice Validates if the source chain is valid for this proxy
     * @param sourceChainId The chain ID to validate
     * @return isValid True if the source chain is valid
     */
    function _isValidSourceChain(
        uint16 sourceChainId
    ) internal view returns (bool isValid) {
        try
            ICrossChainRegistry(crossChainRegistry()).getSourceForTarget(
                sourceChainId,
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
                            sourceChainId,
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
     * @param sourceChainId The source chain ID
     */
    function _handleReceiveAssets(
        address asset,
        uint256 amount,
        uint16 sourceChainId
    ) internal {
        // Approve the fleet contract to take the assets
        IERC20(asset).forceApprove(fleetContract, amount);

        // Deposit the assets into the fleet contract
        IFleetCommander(fleetContract).deposit(amount, address(this));

        // Emit an event for tracking
        emit ProxyDeposit(fleetContract, asset, amount, sourceChainId);
    }
}
