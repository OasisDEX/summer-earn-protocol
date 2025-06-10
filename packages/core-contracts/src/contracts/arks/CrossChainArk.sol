// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {ICrossChainStateReadReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainStateReadReceiver.sol";
import {IInflightAssetTracking} from "@summerfi/chain-bridge/interfaces/IInflightAssetTracking.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IFleetProxy} from "../../interfaces/IFleetProxy.sol";
import {ICrossChainRegistry} from "../../interfaces/ICrossChainRegistry.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title CrossChainArk
 * @notice Ark contract for managing cross-chain deposits and withdrawals
 * @dev Implements strategy for depositing tokens to a satellite chain proxy and handling cross-chain messages.
 *      Supports cross-chain asset reception, state read responses, and inflight asset tracking.
 */
contract CrossChainArk is
    Ark,
    ICrossChainAssetReceiver,
    ICrossChainStateReadReceiver,
    IInflightAssetTracking
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the provided BridgeQueue address is zero.
    error InvalidBridgeQueue();

    /// @notice Thrown when the provided BridgeRouter address is zero.
    error InvalidBridgeRouter();

    /// @notice Thrown when the provided target chain ID is zero.
    error InvalidTargetChain();

    /// @notice Thrown when the provided target proxy address is zero.
    error InvalidTargetProxy();

    /// @notice Thrown when the caller is not authorized to perform the action.
    error Unauthorized();

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

    /// @notice Thrown when receiveMessageWithAssets is called (not supported for this Ark).
    error ReceiveMessageWithAssetsNotSupported();

    /// @notice Thrown when there are insufficient assets on the contract to perform the withdrawal.
    error InsufficientAssets(uint256 requestedAmount, uint256 availableAmount);

    /// @notice Thrown when the provided asset address is invalid.
    error InvalidAsset();

    /// @notice Thrown when the provided registry address is invalid.
    error InvalidRegistry();

    /// @notice Thrown when no proxy relationship is registered for this ark.
    error NoProxyRelationshipRegistered();

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures that a valid proxy relationship exists in the registry
    modifier onlyWithValidProxyRelationship() {
        address proxy = _getTargetProxy();
        if (proxy == address(0)) revert NoProxyRelationshipRegistered();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeQueue contract for queuing cross-chain operations
    IBridgeQueue public immutable bridgeQueue;
    /// @notice The BridgeRouter contract for executing cross-chain operations
    IBridgeRouter public immutable bridgeRouter;
    /// @notice The CrossChainRegistry contract for managing cross-chain relationships
    ICrossChainRegistry public immutable crossChainRegistry;
    /// @notice The target chain ID for cross-chain operations
    uint16 public immutable targetChainId;

    /// @notice Last known remote asset balance (from state read)
    uint256 public lastRemoteAssetBalance;

    /// @notice Amount of assets currently in-flight (being bridged)
    uint256 public inflightAssets;

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

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the CrossChainArk
     * @param _bridgeQueue Address of the BridgeQueue contract
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _crossChainRegistry Address of the CrossChainRegistry contract
     * @param _targetChainId ID of the target chain
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _bridgeQueue,
        address _bridgeRouter,
        address _crossChainRegistry,
        uint16 _targetChainId,
        ArkParams memory _params
    ) Ark(_params) {
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_crossChainRegistry == address(0)) revert InvalidRegistry();
        if (_targetChainId == 0) revert InvalidTargetChain();

        bridgeQueue = IBridgeQueue(_bridgeQueue);
        bridgeRouter = IBridgeRouter(_bridgeRouter);
        crossChainRegistry = ICrossChainRegistry(_crossChainRegistry);
        targetChainId = _targetChainId;
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
        // Only the bridge queue or router should be able to call this
        if (
            msg.sender != address(bridgeQueue) &&
            msg.sender != address(bridgeRouter)
        ) {
            revert Unauthorized();
        }

        inflightAssets = amount;
        emit InflightAssetsUpdated(amount);
    }

    /// @notice Requests a state read to update the remote asset balance
    /// @dev Can be called by keeper or governor to queue a cross-chain state read.
    /// The actual execution (with fees and options) will be done separately by a keeper calling
    /// BridgeQueue.executeQueuedOperation()
    /// @return queueId The ID of the queued state read operation
    function requestRemoteAssetBalanceUpdate()
        external
        onlyKeeper
        onlyWithValidProxyRelationship
        returns (bytes32 queueId)
    {
        address proxyAddress = _getTargetProxy();

        // Queue a state read to get the total assets from the FleetProxy on the target chain
        queueId = bridgeQueue.queueReadState(
            targetChainId,
            proxyAddress,
            IFleetProxy.totalAssets.selector,
            ""
        );

        emit RemoteAssetBalanceUpdateRequested(
            queueId,
            targetChainId,
            proxyAddress
        );
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
     * @return The target proxy address, or address(0) if not registered
     */
    function getTargetProxy() external view returns (address) {
        return _getTargetProxy();
    }

    /**
     * @inheritdoc ICrossChainAssetReceiver
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @param interfaceId The interface ID to check
     * @return True if the contract implements ICrossChainReceiver or ICrossChainAssetReceiver
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        external
        pure
        override(
            ICrossChainAssetReceiver,
            ICrossChainStateReadReceiver,
            IERC165
        )
        returns (bool)
    {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(ICrossChainStateReadReceiver).interfaceId ||
            interfaceId == type(IInflightAssetTracking).interfaceId ||
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
        bytes calldata
    ) internal override onlyWithValidProxyRelationship {
        address proxyAddress = _getTargetProxy();

        // Approve BridgeQueue to spend tokens
        config.asset.approve(address(bridgeQueue), amount);

        bridgeQueue.queueTransferAssets(
            targetChainId,
            address(config.asset),
            amount,
            proxyAddress
        );
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

    /**
     * @inheritdoc ICrossChainStateReadReceiver
     */
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        bytes32 requestId,
        uint16 sourceChainId
    ) external {
        if (msg.sender != address(bridgeRouter)) revert Unauthorized();
        if (sourceChainId != targetChainId) revert InvalidSourceChain();
        if (requestor != address(this)) revert InvalidRequestor();

        // Decode the remote asset balance
        uint256 newRemoteBalance = abi.decode(resultData, (uint256));

        lastRemoteAssetBalance = newRemoteBalance;

        emit RemoteAssetBalanceUpdated(lastRemoteAssetBalance, requestId);

        // Reset inflight assets as the state read now reflects the current remote balance
        inflightAssets = 0;
        emit InflightAssetsUpdated(0);
    }

    /**
     * @inheritdoc ICrossChainAssetReceiver
     */
    function receiveMessageWithAssets(
        address tokenAddress,
        uint256 amount,
        bytes calldata,
        uint16 sourceChainId
    ) external {
        // Allow calls from BridgeRouter or registered bridge adapters
        if (
            msg.sender != address(bridgeRouter) &&
            !bridgeRouter.isValidAdapter(msg.sender)
        ) {
            revert Unauthorized();
        }
        if (sourceChainId != targetChainId) revert InvalidSourceChain();
        if (tokenAddress != address(config.asset)) revert InvalidAsset();

        // Update the remote asset tracking
        // Since we've received these assets, we can reduce the remote balance
        if (amount <= lastRemoteAssetBalance) {
            lastRemoteAssetBalance -= amount;
        } else {
            lastRemoteAssetBalance = 0;
        }

        emit AssetsReceived(tokenAddress, amount, sourceChainId);
    }

    /**
     * @notice Gets the target proxy address from the registry
     * @return proxyAddress The target proxy address, or address(0) if not registered
     */
    function _getTargetProxy() internal view returns (address proxyAddress) {
        try crossChainRegistry.getProxyForArk(address(this)) returns (
            address proxy,
            uint16 chainId
        ) {
            if (proxy != address(0) && chainId == targetChainId) {
                return proxy;
            }
        } catch {
            // Registry lookup failed, return address(0)
        }
        return address(0);
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
