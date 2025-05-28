// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {ICrossChainArk} from "@summerfi/chain-bridge/interfaces/ICrossChainArk.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {IFleetProxy} from "../../interfaces/IFleetProxy.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title CrossChainArk
 * @notice Ark contract for managing cross-chain deposits and withdrawals
 * @dev Implements strategy for depositing tokens to a satellite chain proxy and handling cross-chain messages
 */
contract CrossChainArk is Ark, ICrossChainAssetReceiver, ICrossChainArk {
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

    /// @notice Thrown when receiveMessage is called (not supported for this Ark).
    error ReceiveMessageNotSupported();

    /// @notice Thrown when receiveMessageWithAssets is called (not supported for this Ark).
    error ReceiveMessageWithAssetsNotSupported();

    /// @notice Thrown when there are insufficient assets on the contract to perform the withdrawal.
    error InsufficientAssets(uint256 requestedAmount, uint256 availableAmount);

    /// @notice Thrown when the provided asset address is invalid.
    error InvalidAsset();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The BridgeQueue contract for queuing cross-chain operations
    IBridgeQueue public immutable bridgeQueue;
    /// @notice The BridgeRouter contract for executing cross-chain operations
    IBridgeRouter public immutable bridgeRouter;
    /// @notice The target chain ID for cross-chain operations
    uint16 public immutable targetChainId;
    /// @notice The target proxy address on the satellite chain
    address public targetProxy;

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

    /// @notice Emitted when the target proxy is updated
    event TargetProxyUpdated(
        address indexed oldProxy,
        address indexed newProxy
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
     * @param _targetChainId ID of the target chain
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _bridgeQueue,
        address _bridgeRouter,
        uint16 _targetChainId,
        ArkParams memory _params
    ) Ark(_params) {
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_targetChainId == 0) revert InvalidTargetChain();

        bridgeQueue = IBridgeQueue(_bridgeQueue);
        bridgeRouter = IBridgeRouter(_bridgeRouter);
        targetChainId = _targetChainId;

        // targetProxy is initialized to address(0) by default and must be set later
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set new target proxy address
    /// @param _targetProxy The new target proxy address
    function setTargetProxy(address _targetProxy) external onlyGovernor {
        if (_targetProxy == address(0)) revert InvalidTargetProxy();

        address oldProxy = targetProxy;
        targetProxy = _targetProxy;
        emit TargetProxyUpdated(oldProxy, _targetProxy);
    }

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
        returns (bytes32 queueId)
    {
        if (targetProxy == address(0)) revert InvalidTargetProxy();

        // Queue a state read to get the total assets from the FleetProxy on the target chain
        queueId = bridgeQueue.queueReadState(
            targetChainId,
            targetProxy,
            IFleetProxy.totalAssets.selector,
            ""
        );

        emit RemoteAssetBalanceUpdateRequested(
            queueId,
            targetChainId,
            targetProxy
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
     * @inheritdoc ICrossChainAssetReceiver
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @param interfaceId The interface ID to check
     * @return True if the contract implements ICrossChainReceiver or ICrossChainAssetReceiver
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override(ICrossChainAssetReceiver, IERC165) returns (bool) {
        return
            interfaceId == type(ICrossChainAssetReceiver).interfaceId ||
            interfaceId == type(ICrossChainArk).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Boards the Ark by initiating a cross-chain transfer
     * @param amount Amount of tokens to transfer
     * @dev This function queues a cross-chain transfer to the target proxy
     */
    function _board(uint256 amount, bytes calldata) internal override {
        // Ensure targetProxy is set
        if (targetProxy == address(0)) revert InvalidTargetProxy();

        // Approve BridgeQueue to spend tokens
        config.asset.approve(address(bridgeQueue), amount);

        bridgeQueue.queueTransferAssets(
            targetChainId,
            address(config.asset),
            amount,
            targetProxy
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
     * @notice Receives state read results from another chain
     * @param resultData The data returned from the cross-chain read
     * @param requestor The address that initiated the request
     * @param sourceChainId The chain ID where the data was read from
     * @param requestId The unique ID of the original request
     */
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external {
        if (msg.sender != address(bridgeRouter)) revert Unauthorized();
        if (sourceChainId != targetChainId) revert InvalidSourceChain();
        if (requestor != address(this)) revert InvalidRequestor();

        // Decode the remote asset balance
        uint256 newRemoteBalance = abi.decode(resultData, (uint256));

        lastRemoteAssetBalance = newRemoteBalance;

        // Reset inflight assets as the state read now reflects the current remote balance
        inflightAssets = 0;
        emit InflightAssetsUpdated(0);

        emit RemoteAssetBalanceUpdated(lastRemoteAssetBalance, requestId);
    }

    /**
     * @notice Receives a general cross-chain message (not supported)
     */
    function receiveMessage(
        bytes calldata,
        address,
        uint16,
        bytes32
    ) external pure {
        revert ReceiveMessageNotSupported();
    }

    /**
     * @inheritdoc ICrossChainAssetReceiver
     * @notice Receives assets from another chain along with a message
     * @param tokenAddress The address of the received token
     * @param amount The amount of tokens received
     * @param // message The associated message data
     * @param sourceChainId The chain ID where the message originated from
     */
    function receiveMessageWithAssets(
        address tokenAddress,
        uint256 amount,
        bytes calldata, // TODO: Use this to send latest true balance after withdrawal
        uint16 sourceChainId
    ) external {
        if (msg.sender != address(bridgeRouter)) revert Unauthorized();
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
