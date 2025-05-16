// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";

contract MockAdapter is IBridgeAdapter {
    address public bridgeRouter;

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

    constructor(address _bridgeRouter) {
        bridgeRouter = _bridgeRouter;

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

    /// @inheritdoc ISendAdapter
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32 transferId) {
        // Check caller is bridge router
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Verify chain and asset are supported
        if (!this.supportsChain(destinationChainId)) revert UnsupportedChain();

        // Generate deterministic transfer ID for testing
        transferId = keccak256(
            abi.encodePacked(
                block.chainid,
                destinationChainId,
                asset,
                recipient,
                amount
            )
        );

        // Mock transfer successful - emit event for testing
        emit MockTransferInitiated(
            transferId,
            destinationChainId,
            asset,
            recipient,
            amount,
            originator
        );

        return transferId;
    }

    /// @inheritdoc ISendAdapter
    function readState(
        uint16 srcChainId,
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes calldata readParams,
        address originator,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32 requestId) {
        // Check caller is bridge router
        if (msg.sender != bridgeRouter) revert Unauthorized();

        // Verify chain is supported
        if (!this.supportsChain(dstChainId)) revert UnsupportedChain();

        // Generate deterministic request ID for testing
        requestId = keccak256(
            abi.encodePacked(
                block.chainid,
                srcChainId,
                dstChainId,
                dstContract,
                selector,
                readParams
            )
        );

        // Mock read successful - emit event for testing
        emit MockReadInitiated(
            requestId,
            srcChainId,
            dstChainId,
            dstContract,
            selector,
            readParams,
            originator
        );

        return requestId;
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        // Return base fee of 0.1 ETH to match the router's base fee
        nativeFee = 0.1 ether;
        tokenFee = 0;
    }

    /// @inheritdoc IBridgeAdapter
    function getOperationStatus(
        bytes32 operationId
    ) external view override returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 111; // SOURCE_CHAIN_ID from tests
        return chains;
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
        uint16 dstChainId,
        address dstContract,
        bytes4 selector,
        bytes readParams,
        address originator
    );

    event MockComposeInitiated(
        bytes32 requestId,
        uint16 destinationChainId,
        bytes[] actions,
        address originator
    );

    /// @inheritdoc ISendAdapter
    function sendMessage(
        uint16,
        address,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert("Not implemented");
    }

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

        // Notify the bridge router about the received message
        IBridgeRouter(bridgeRouter).notifyMessageReceived(
            messageId,
            address(0), // No asset for general message
            0, // No amount for general message
            sender, // The destination contract address
            sourceChainId
        );

        emit MessageRelayed(messageId, sender, sourceChainId);
    }
}
