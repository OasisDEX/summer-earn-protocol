// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ProtocolAccessManaged, ContractSpecificRoles} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
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
    ProtocolAccessManaged,
    ReentrancyGuard,
    Pausable
{
    using SafeERC20 for IERC20;

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

    /// @notice The address of the source chain's CrossChainArk (DEPRECATED: Use crossChainRegistry instead)
    /// @dev This field is kept for backward compatibility but marked as deprecated
    address public sourceChainArk;

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

    /// @notice Emitted when the source chain ark address is updated
    event SourceChainArkUpdated(address indexed newSourceChainArk);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the CrossChainFleetProxy
     * @param _accessManager Address of the access manager
     * @param _bridgeRouter Address of the bridge router
     * @param _bridgeQueue Address of the bridge queue
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _fleetContract Address of the Fleet contract this proxy covers
     */
    constructor(
        address _accessManager,
        address _bridgeRouter,
        address _bridgeQueue,
        address _crossChainRegistry,
        address _fleetContract
    ) ProtocolAccessManaged(_accessManager) {
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_crossChainRegistry == address(0)) revert InvalidRegistry();
        if (_fleetContract == address(0)) revert InvalidFleetContract();

        bridgeRouter = IBridgeRouter(_bridgeRouter);
        bridgeQueue = IBridgeQueue(_bridgeQueue);
        crossChainRegistry = ICrossChainRegistry(_crossChainRegistry);
        fleetContract = _fleetContract;

        // sourceChainArk is initialized to address(0) by default for backward compatibility
        // New deployments should use the registry instead
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

    /// @notice Updates the source chain ark address (DEPRECATED: Use registry instead)
    /// @param _sourceChainArk The new source chain ark address
    /// @dev This function is deprecated. New deployments should register relationships via CrossChainRegistry
    function setSourceChainArk(address _sourceChainArk) external onlyGovernor {
        if (_sourceChainArk == address(0)) revert InvalidSourceChainArk();
        sourceChainArk = _sourceChainArk;
        emit SourceChainArkUpdated(_sourceChainArk);
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
    ) external whenNotPaused nonReentrant onlyKeeper {
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

        // 5. Get source chain ark address using registry first, then fallback to deprecated field
        address arkAddress = _getSourceChainArk(sourceChainId);
        if (arkAddress == address(0)) revert InvalidSourceChainArk();

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

        // Validate the relationship using registry first, then fallback
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
     * @notice Gets the source chain ark address, trying registry first then fallback to deprecated field
     * @param sourceChainId The chain ID where the ark is deployed
     * @return arkAddress The source chain ark address, or address(0) if not found
     * @dev This function provides backward compatibility while transitioning to registry-based lookups
     */
    function _getSourceChainArk(
        uint16 sourceChainId
    ) internal view returns (address arkAddress) {
        // Try to get from registry first
        try
            crossChainRegistry.getArkForProxy(sourceChainId, address(this))
        returns (address ark) {
            if (ark != address(0)) {
                return ark;
            }
        } catch {
            // Registry lookup failed, fall back to deprecated field
        }

        // Fallback to deprecated sourceChainArk field for backward compatibility
        return sourceChainArk;
    }

    /**
     * @notice Validates if the source chain is valid for this proxy
     * @param sourceChainId The chain ID to validate
     * @return isValid True if the source chain is valid
     * @dev This function checks the registry first, then falls back to basic validation
     */
    function _isValidSourceChain(
        uint16 sourceChainId
    ) internal view returns (bool isValid) {
        // Try to validate using registry first
        try
            crossChainRegistry.getArkForProxy(sourceChainId, address(this))
        returns (address ark) {
            if (ark != address(0)) {
                // Additional validation: check if the relationship is active
                try
                    crossChainRegistry.isValidArkProxyPair(
                        ark,
                        sourceChainId,
                        address(this)
                    )
                returns (bool isValidPair) {
                    return isValidPair;
                } catch {
                    return true; // If validation fails, assume true for backward compatibility
                }
            }
        } catch {
            // Registry lookup failed
        }

        // Fallback: if we have a configured sourceChainArk, consider it valid
        return sourceChainArk != address(0);
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

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Error thrown when source chain ark address is invalid
    error InvalidSourceChainArk();
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
    /// @notice Thrown when the caller is not authorized to perform the action.
    error Unauthorized();
    /// @notice Error thrown when source chain is invalid
    error InvalidSourceChain();
}
