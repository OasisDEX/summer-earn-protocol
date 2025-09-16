// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/// forge-lint: disable-start(unused-import)
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {IAssetAdapter} from "../../src/interfaces/IAssetAdapter.sol";
import {IMessageAdapter} from "../../src/interfaces/IMessageAdapter.sol";
/// forge-lint: disable-end(unused-import)
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";
import {BaseBridgeAdapter} from "../../src/base/BaseBridgeAdapter.sol";

contract MockAdapter is
    BaseBridgeAdapter,
    IAssetAdapter,
    IMessageAdapter,
    IBridgeAdapter
{
    using SafeERC20 for IERC20;

    // Add a fee multiplier state variable with a default value of 100 (100%)
    uint256 public feeMultiplier = 100;

    // Add mappings to track supported chains and assets
    mapping(uint16 => bool) public supportedChains;

    // Add mapping to track supported operations
    mapping(BridgeTypes.OperationType => bool) public supportedOperations;

    // Add mapping to track operation statuses
    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;

    // Storage for received data
    bytes public lastReceivedResponse;
    address public lastReceivedSender;
    uint16 public lastReceivedChainId;
    bytes32 public lastReceivedRequestId;

    // Additional storage for tracking new interface method calls
    address public lastReceivedAsset;
    uint256 public lastReceivedAmount;
    address public lastReceivedRecipient;
    bytes public lastReceivedExtraData;

    // Mapping of operation types to message types (similar to LayerZeroAdapter)
    mapping(BridgeTypes.OperationType => uint16) private operationToMessageType;

    // Add ReceivedMessage struct from core-contracts version
    struct ReceivedMessage {
        bytes message;
        address sender;
        uint16 sourceChainId;
        bytes32 messageId;
    }

    ReceivedMessage[] public receivedMessages;

    // Add MessageRelayed event from core-contracts version
    event MessageRelayed(
        bytes32 messageId,
        address recipient,
        uint16 sourceChainId
    );

    constructor(
        address _registry,
        address _accessManager
    ) BaseBridgeAdapter(_registry, _accessManager) {
        // Initialize operation type to message type mapping (for consistency)
        operationToMessageType[BridgeTypes.OperationType.MESSAGE] = 1; // Mock message type
        operationToMessageType[BridgeTypes.OperationType.READ_STATE] = 2; // Mock read type
        operationToMessageType[BridgeTypes.OperationType.TRANSFER_ASSET] = 3; // Mock transfer type

        // Initialize default supported chain for testing
        supportedChains[111] = true; // SOURCE_CHAIN_ID from tests

        // Initialize default supported operations
        supportedOperations[BridgeTypes.OperationType.MESSAGE] = true;
        supportedOperations[BridgeTypes.OperationType.READ_STATE] = true;
        supportedOperations[BridgeTypes.OperationType.TRANSFER_ASSET] = true;
    }

    // Add helper function to set fee multiplier
    function setFeeMultiplier(uint256 _multiplier) external {
        feeMultiplier = _multiplier;
    }

    // Add helper functions to configure supported chains and assets
    function setSupportedChain(uint16 chainId, bool supported) external {
        supportedChains[chainId] = supported;
    }

    // Add helper function to configure supported operations
    function setSupportedOperation(
        BridgeTypes.OperationType operationType,
        bool supported
    ) external {
        supportedOperations[operationType] = supported;
    }

    /// @inheritdoc IAssetAdapter
    function transferAsset(
        bytes32 operationId, // Accept from router
        BridgeTypes.ExecuteTransferParams calldata params,
        BridgeTypes.BridgeOptions calldata /* options */
    ) external payable onlyRouter {
        // Verify chain and asset are supported
        if (!this.supportsChain(params.destinationChainId)) {
            revert UnsupportedChain();
        }

        // Transfer tokens from BridgeRouter to this contract (like real adapters do)
        IERC20(params.asset).safeTransferFrom(
            msg.sender,
            address(this),
            params.amount
        );

        // Use the provided operation ID (don't generate our own)
        emit MockTransferInitiated(
            operationId, // Use router's ID
            params.destinationChainId,
            params.asset,
            params.target,
            params.amount,
            params.originator
        );

        // No return value needed
    }

    /// @inheritdoc IMessageAdapter
    function readState(
        bytes32 operationId, // Accept from router
        BridgeTypes.ExecuteReadStateParams calldata params,
        BridgeTypes.BridgeOptions calldata /* options */
    ) external payable onlyRouter {
        // Verify chain is supported
        if (!this.supportsChain(params.destinationChainId))
            revert UnsupportedChain();

        // Use the provided operation ID (don't generate our own)
        emit MockReadInitiated(
            operationId, // Use router's ID
            uint16(0),
            params.destinationChainId,
            params.target,
            params.selector,
            params.readParams
        );

        // No return value needed
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16 destinationChainId,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.BridgeOptions calldata /* options */,
        BridgeTypes.OperationType /* operationType */
    ) external view returns (uint256 nativeFee, uint256 tokenFee) {
        // Check if chain is supported
        if (!supportedChains[destinationChainId]) {
            revert UnsupportedChain();
        }

        // Return base fee of 0.1 ETH multiplied by the fee multiplier
        nativeFee = (0.1 ether * feeMultiplier) / 100;
        tokenFee = 0;
    }

    function supportsChain(uint16 chainId) external view returns (bool) {
        return supportedChains[chainId];
    }

    /// @inheritdoc IBridgeAdapter
    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external view returns (bool) {
        return supportedOperations[operationType];
    }

    event ActionComposed(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        uint256 actionCount
    );

    event MockTransferInitiated(
        bytes32 transferId,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator
    );

    event MockReadInitiated(
        bytes32 requestId,
        uint16 srcChainId,
        uint16 destinationChainId,
        address destinationContract,
        bytes4 selector,
        bytes readParams
    );

    /// @inheritdoc IMessageAdapter
    function sendMessage(
        bytes32 operationId, // Accept from router
        BridgeTypes.ExecuteSendMessageParams calldata params,
        BridgeTypes.BridgeOptions calldata /* options */
    ) external payable onlyRouter {
        // Verify chain is supported
        if (!this.supportsChain(params.destinationChainId))
            revert UnsupportedChain();

        // Use the provided operation ID (don't generate our own)
        emit MockMessageInitiated(
            operationId, // Use router's ID
            params.destinationChainId,
            params.target,
            params.message
        );

        // No return value needed
    }

    event MockMessageInitiated(
        bytes32 messageId,
        uint16 destinationChainId,
        address recipient,
        bytes message
    );

    // Add simulateMessageReceived function from core-contracts version
    function simulateMessageReceived(
        bytes memory message,
        address sender,
        uint16 sourceChainId,
        bytes32 messageId
    ) external {
        // Store the received message
        receivedMessages.push(
            ReceivedMessage({
                message: message,
                sender: sender,
                sourceChainId: sourceChainId,
                messageId: messageId
            })
        );

        emit MessageRelayed(messageId, sender, sourceChainId);
    }

    // Simple test function to check if function calls work
    function testFunction() external pure returns (bool) {
        console.log("testFunction called successfully");
        return true;
    }

    // Minimal version of transferAsset for debugging
    function transferAssetMinimal(
        bytes32 operationId,
        uint16 destinationChainId,
        address /* asset */,
        address /* recipient */,
        uint256 /* amount */,
        address /* originator */
    ) external payable {
        console.log("transferAssetMinimal called successfully");
        console.log("operationId:", uint256(operationId));
        console.log("destinationChainId:", destinationChainId);
    }

    function testSkipper() public {}

    /// @inheritdoc IAssetAdapter
    function supportsAssetTransfer(
        uint16 destinationChainId,
        address /* asset */
    ) external view returns (bool) {
        return
            supportedChains[destinationChainId] &&
            supportedOperations[BridgeTypes.OperationType.TRANSFER_ASSET];
    }

    /// @inheritdoc IMessageAdapter
    function supportsMessageOperation(
        uint16 destinationChainId,
        BridgeTypes.OperationType operationType
    ) external view returns (bool) {
        return
            supportedChains[destinationChainId] &&
            supportedOperations[operationType] &&
            (operationType == BridgeTypes.OperationType.MESSAGE ||
                operationType == BridgeTypes.OperationType.READ_STATE);
    }
}
