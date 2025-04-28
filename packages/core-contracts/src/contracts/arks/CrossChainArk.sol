// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../Ark.sol";
import {ICrossChainReceiver} from "@summerfi/chain-bridge/src/interfaces/ICrossChainReceiver.sol";
import {IBridgeQueue} from "@summerfi/chain-bridge/src/interfaces/IBridgeQueue.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "@summerfi/chain-bridge/src/libraries/BridgeTypes.sol";

error InvalidBridgeQueue();
error InvalidBridgeRouter();
error InvalidTargetChain();
error InvalidTargetProxy();
error InvalidOperationId();
error InvalidMessageId();

/**
 * @title CrossChainArk
 * @notice Ark contract for managing cross-chain deposits and withdrawals
 * @dev Implements strategy for depositing tokens to a satellite chain proxy and handling cross-chain messages
 */
contract CrossChainArk is Ark, ICrossChainReceiver {
    using SafeERC20 for IERC20;

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
    /// @notice Mapping of operation IDs to their status
    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatus;
    /// @notice Mapping of message IDs to their status
    mapping(bytes32 => BridgeTypes.OperationStatus) public messageStatus;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to set up the CrossChainArk
     * @param _bridgeQueue Address of the BridgeQueue contract
     * @param _bridgeRouter Address of the BridgeRouter contract
     * @param _targetChainId ID of the target chain
     * @param _targetProxy Address of the target proxy on the satellite chain
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _bridgeQueue,
        address _bridgeRouter,
        uint16 _targetChainId,
        address _targetProxy,
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
        assets = config.asset.balanceOf(address(this));
    }

    /**
     * @inheritdoc ICrossChainReceiver
     * @notice Checks if this contract supports the CrossChainReceiver interface
     * @param interfaceId The interface ID to check
     * @return True if the contract implements ICrossChainReceiver
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return interfaceId == type(ICrossChainReceiver).interfaceId;
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
        // Queue the cross-chain transfer
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            adapter: address(0), // Let the bridge queue choose the best adapter
            gasLimit: 0, // Use default gas limit
            maxFee: 0, // No max fee limit
            params: bytes("") // No additional params needed
        });

        bytes32 queueId = bridgeQueue.queueTransferAssets(
            targetChainId,
            address(config.asset),
            amount,
            targetProxy,
            options
        );

        // Store the operation status
        operationStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;
    }

    /**
     * @notice Disembarks the Ark by initiating a cross-chain withdrawal
     * @param amount Amount of tokens to withdraw
     * @dev This function queues a cross-chain withdrawal from the target proxy
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        // Queue the cross-chain withdrawal
        BridgeTypes.BridgeOptions memory options = BridgeTypes.BridgeOptions({
            adapter: address(0), // Let the bridge queue choose the best adapter
            gasLimit: 0, // Use default gas limit
            maxFee: 0, // No max fee limit
            params: bytes("") // No additional params needed
        });

        bytes32 queueId = bridgeQueue.queueTransferAssets(
            targetChainId,
            address(config.asset),
            amount,
            address(this), // Withdraw to this contract
            options
        );

        // Store the operation status
        operationStatus[queueId] = BridgeTypes.OperationStatus.QUEUED;
    }

    /**
     * @inheritdoc ICrossChainReceiver
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
        if (sourceChainId != targetChainId) revert InvalidTargetChain();
        if (requestor != address(this)) revert Unauthorized();
        if (operationStatus[requestId] != BridgeTypes.OperationStatus.QUEUED) {
            revert InvalidOperationId();
        }

        // Update operation status
        operationStatus[requestId] = BridgeTypes.OperationStatus.COMPLETED;

        // Process the result data if needed
        // This could be used to verify the state of the target proxy
    }

    /**
     * @inheritdoc ICrossChainReceiver
     * @notice Receives a general cross-chain message
     * @param message The message content
     * @param recipient The intended recipient of the message
     * @param sourceChainId The chain ID where the message originated
     * @param messageId The unique ID of the message
     */
    function receiveMessage(
        bytes calldata message,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) external {
        if (msg.sender != address(bridgeRouter)) revert Unauthorized();
        if (sourceChainId != targetChainId) revert InvalidTargetChain();
        if (recipient != address(this)) revert Unauthorized();
        if (messageStatus[messageId] != BridgeTypes.OperationStatus.QUEUED) {
            revert InvalidMessageId();
        }

        // Update message status
        messageStatus[messageId] = BridgeTypes.OperationStatus.COMPLETED;

        // Process the message if needed
        // This could be used to handle notifications from the target proxy
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
}
