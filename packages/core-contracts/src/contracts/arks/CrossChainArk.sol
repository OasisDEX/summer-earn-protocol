// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ICrossChainAssetReceiver} from "@summerfi/chain-bridge/interfaces/ICrossChainAssetReceiver.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {ProtocolAccessManagedExt} from "@summerfi/access-contracts/contracts/ProtocolAccessManagedExt.sol";

/**
 * @title CrossChainArk
 * @notice Ark contract for managing cross-chain deposits and withdrawals
 * @dev Implements strategy for depositing tokens to a satellite chain proxy and handling cross-chain messages
 */
contract CrossChainArk is
    Ark,
    ICrossChainAssetReceiver,
    ProtocolAccessManagedExt
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

    /// @notice Thrown when receiveMessage is called (not supported for this Ark).
    error ReceiveMessageNotSupported();

    /// @notice Thrown when receiveMessageWithAssets is called (not supported for this Ark).
    error ReceiveMessageWithAssetsNotSupported();

    /// @notice Thrown when there are insufficient assets on the contract to perform the withdrawal.
    error InsufficientAssets(uint256 requestedAmount, uint256 availableAmount);

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
    address public immutable targetProxy;

    /// @notice Configurable bridge options for cross-chain actions
    BridgeTypes.BridgeOptions public bridgeOptions;

    /// @notice Last known remote asset balance (from state read)
    uint256 public lastRemoteAssetBalance;

    /// @notice Assets that have been queued for transfer but not yet confirmed on target chain
    uint256 public inFlightAssets;

    event BridgeOptionsUpdated(BridgeTypes.BridgeOptions newOptions);

    /// @notice Emitted when the remote asset balance is updated via state read
    event RemoteAssetBalanceUpdated(uint256 newBalance, bytes32 requestId);

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the CrossChainArk
     * @param _bridgeQueue Address of the BridgeQueue contract
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _targetChainId ID of the target chain
     * @param _targetProxy Address of the target proxy on the satellite chain
     * @param _initialBridgeOptions Initial bridge options for cross-chain actions
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _bridgeQueue,
        address _bridgeRouter,
        uint16 _targetChainId,
        address _targetProxy,
        BridgeTypes.BridgeOptions memory _initialBridgeOptions,
        ArkParams memory _params
    ) Ark(_params) {
        if (_bridgeQueue == address(0)) revert InvalidBridgeQueue();
        if (_bridgeRouter == address(0)) revert InvalidBridgeRouter();
        if (_targetChainId == 0) revert InvalidTargetChain();
        if (_targetProxy == address(0)) revert InvalidTargetProxy();

        bridgeQueue = IBridgeQueue(_bridgeQueue);
        bridgeRouter = IBridgeRouter(_bridgeRouter);
        targetChainId = _targetChainId;
        targetProxy = _targetProxy;
        bridgeOptions = _initialBridgeOptions;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Set new bridge options
    function setBridgeOptions(
        BridgeTypes.BridgeOptions calldata newOptions
    ) external onlyGovernorOrKeeper {
        bridgeOptions = newOptions;
        emit BridgeOptionsUpdated(newOptions);
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
            inFlightAssets;
    }

    /**
     * @inheritdoc ICrossChainAssetReceiver
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @param interfaceId The interface ID to check
     * @return True if the contract implements ICrossChainReceiver or ICrossChainAssetReceiver
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(ICrossChainAssetReceiver).interfaceId;
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
        // Approve BridgeQueue to spend tokens
        config.asset.approve(address(bridgeQueue), amount);

        // Track the in-flight assets
        inFlightAssets += amount;

        bridgeQueue.queueTransferAssets(
            targetChainId,
            address(config.asset),
            amount,
            targetProxy,
            bridgeOptions
        );
    }

    /**
     * @notice Disembarks the Ark by withdrawing assets that are available on the contract
     * @param amount Amount of tokens to withdraw
     * @dev This function only validates that enough assets are available on this contract
     * The actual withdrawal from the satellite chain is processed by a keeper through
     * FleetProxy.withdrawAndTransfer() which transfers assets back to this contract
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
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

        // Reset in-flight assets as we now have confirmed remote balance
        inFlightAssets = 0;
        lastRemoteAssetBalance = newRemoteBalance;

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
     * @notice Receives a message with assets (not supported for this Ark)
     */
    function receiveMessageWithAssets(
        address,
        uint256,
        bytes calldata,
        uint16
    ) external pure {
        revert ReceiveMessageWithAssetsNotSupported();
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
