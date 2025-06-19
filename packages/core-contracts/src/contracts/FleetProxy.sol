// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {DeploymentAccessManaged} from "@summerfi/access-contracts/contracts/DeploymentAccessManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {IFleetProxy} from "../interfaces/IFleetProxy.sol";
import {IFleetCommanderConfigProvider} from "../interfaces/IFleetCommanderConfigProvider.sol";
import {FleetConfig} from "../types/FleetCommanderTypes.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {ICrossChainRegistry} from "../interfaces/ICrossChainRegistry.sol";

/**
 * @title FleetProxy
 * @author SummerFi
 * @notice Proxy contract that receives and holds assets on a satellite chain on behalf of a source chain fleet
 * @dev Implements ICrossChainReceiver to handle cross-chain messages
 */
contract FleetProxy is
    IFleetProxy,
    IInflightAssetTracking,
    DeploymentAccessManaged,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when bridge router address is invalid
    error InvalidBridgeRouter();
    /// @notice Error thrown when bridge queue address is invalid
    error InvalidBridgeQueue();
    /// @notice Error thrown when registry address is invalid
    error InvalidRegistry();
    /// @notice Error thrown when fleet contract address is invalid
    error InvalidFleetContract();
    /// @notice Error thrown when withdrawal failed
    error WithdrawalFailed();
    /// @notice Error thrown when no ark relationship is registered for this proxy
    error NoArkRelationshipRegistered();
    /// @notice Thrown when the caller is not authorized to perform the action.
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures that a valid ark relationship exists in the registry for the given source chain
    modifier onlyWithValidArkRelationship(uint16 sourceChainId) {
        address ark = _getSourceChainArk(sourceChainId);
        if (ark == address(0)) revert NoArkRelationshipRegistered();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The bridge router used for cross-chain communication
    IBridgeRouter public immutable bridgeRouter;

    /// @notice The bridge queue used for queuing cross-chain transfers
    IBridgeQueue public immutable bridgeQueue;

    /// @notice The CrossChainRegistry contract for managing cross-chain relationships
    ICrossChainRegistry public immutable crossChainRegistry;

    /// @notice The address of the Fleet contract that this proxy covers
    address public immutable fleetContract;

    /// @notice Amount of withdrawal assets currently in-flight (being bridged back)
    uint256 public inflightWithdrawals;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when assets are withdrawn and transferred back to source chain
    event AssetsWithdrawnAndTransferred(
        uint256 amount,
        address asset,
        uint16 sourceChainId
    );

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param initialController Address of the initial controller (deployer)
     * @param accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _bridgeQueue Address of the bridge queue
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _fleetContract Address of the Fleet contract this proxy covers
     */
    constructor(
        address initialController,
        address accessManager,
        address _bridgeRouter,
        address _bridgeQueue,
        address _crossChainRegistry,
        address _fleetContract
    ) DeploymentAccessManaged(initialController, accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_crossChainRegistry == address(0)) revert InvalidRegistry();
        if (_fleetContract == address(0)) revert InvalidFleetContract();

        bridgeRouter = IBridgeRouter(_bridgeRouter);
        bridgeQueue = IBridgeQueue(_bridgeQueue);
        crossChainRegistry = ICrossChainRegistry(_crossChainRegistry);
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
        if (
            msg.sender != address(bridgeQueue) &&
            msg.sender != address(bridgeRouter)
        ) {
            revert Unauthorized();
        }

        inflightWithdrawals = amount;
        emit InflightAssetsUpdated(amount);
    }

    /// @notice Keeper function to withdraw and transfer assets
    function withdrawAndTransfer(
        uint256 amount,
        uint16 sourceChainId
    )
        external
        whenNotPaused
        nonReentrant
        onlyKeeper
        onlyWithValidArkRelationship(sourceChainId)
    {
        if (amount == 0) revert NoAssets();

        // 1. Get the asset from fleet config
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        address asset = address(config.bufferArk.asset());

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
        IERC20(asset).approve(address(bridgeQueue), amount);

        // 5. Get source chain ark address from registry
        address arkAddress = _getSourceChainArk(sourceChainId);

        // 6. Use BridgeQueue to queue a transfer of assets back to source chain's CrossChainArk
        bridgeQueue.queueTransferAssets(
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
        if (!bridgeRouter.isValidAdapter(msg.sender)) {
            revert CallerNotRegisteredAdapter();
        }

        // Validate the relationship using registry
        if (!_isValidSourceChain(sourceChainId)) {
            revert InvalidSourceChain();
        }

        // Get the fleet config and check if the asset matches
        FleetConfig memory config = IFleetCommanderConfigProvider(fleetContract)
            .getConfig();
        if (asset != address(config.bufferArk.asset())) {
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
     * @return arkAddress The source chain ark address, or address(0) if not found
     */
    function _getSourceChainArk(
        uint16 sourceChainId
    ) internal view returns (address arkAddress) {
        try
            crossChainRegistry.getArkForProxy(sourceChainId, address(this))
        returns (address ark) {
            if (ark != address(0)) {
                return ark;
            }
        } catch {
            // Registry lookup failed
        }
        return address(0);
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
            crossChainRegistry.getArkForProxy(sourceChainId, address(this))
        returns (address ark) {
            if (ark != address(0)) {
                try
                    crossChainRegistry.isValidArkProxyPair(
                        ark,
                        sourceChainId,
                        address(this)
                    )
                returns (bool isValidPair) {
                    return isValidPair;
                } catch {
                    return false; // If validation fails, deny access
                }
            }
        } catch {
            // Registry lookup failed
        }
        return false;
    }

    /**
     * @notice Handle receiving assets from the source chain
     * @param token Address of the token
     * @param amount Amount of tokens
     * @param sourceChainId Source chain ID
     */
    function _handleReceiveAssets(
        address token,
        uint256 amount,
        uint16 sourceChainId
    ) internal {
        // Deposit the assets into the underlying fleet contract
        // First approve the fleetContract to spend the tokens
        IERC20(token).approve(fleetContract, amount);

        // Deposit assets into the fleet contract
        IFleetCommander(fleetContract).deposit(
            amount,
            address(this),
            bytes("")
        );

        // Emit event for tracking
        emit ProxyDeposit(fleetContract, token, amount, sourceChainId);
    }
}
