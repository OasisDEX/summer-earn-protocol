// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";

contract MockAdapter is IBridgeAdapter {
    address public bridgeRouter;

    // Add a fee multiplier state variable with a default value of 100 (100%)
    uint256 public feeMultiplier = 100;

    // Add mappings to track supported chains and assets
    mapping(uint16 => bool) public supportedChains;
    mapping(uint16 => mapping(address => bool)) public supportedAssets;

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

    constructor(address _bridgeRouter) {
        bridgeRouter = _bridgeRouter;

        // Initialize operation type to message type mapping (for consistency)
        operationToMessageType[BridgeTypes.OperationType.MESSAGE] = 1; // Mock message type
        operationToMessageType[BridgeTypes.OperationType.READ_STATE] = 2; // Mock read type
        operationToMessageType[BridgeTypes.OperationType.TRANSFER_ASSET] = 3; // Mock transfer type
    }

    // Add helper function to set fee multiplier
    function setFeeMultiplier(uint256 _multiplier) external {
        feeMultiplier = _multiplier;
    }

    // Add helper functions to configure supported chains and assets
    function setSupportedChain(uint16 chainId, bool supported) external {
        supportedChains[chainId] = supported;
    }

    function setSupportedAsset(
        uint16 chainId,
        address asset,
        bool supported
    ) external {
        supportedAssets[chainId][asset] = supported;
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
        if (!this.supportsAsset(destinationChainId, asset))
            revert UnsupportedAsset();

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
        uint256 amount,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType operationType
    ) external view returns (uint256 nativeFee, uint256 tokenFee) {
        // Mock implementation that uses operation type
        uint16 messageType = operationToMessageType[operationType];

        // In a real implementation, the message type would affect the fee calculation
        // For the mock, we'll just add the message type to the base fee
        uint256 baseFee = (amount > 0) ? amount : 1 ether;

        // Return fee based on multiplier and message type
        nativeFee = (baseFee * feeMultiplier * messageType) / 100;
        return (nativeFee, 0);
    }

    /// @inheritdoc IBridgeAdapter
    function getOperationStatus(
        bytes32 operationId
    ) external view override returns (BridgeTypes.OperationStatus) {
        return operationStatuses[operationId];
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedChains()
        external
        view
        override
        returns (uint16[] memory)
    {
        // Count supported chains first
        uint256 count = 0;
        for (uint16 i = 0; i < 1000; i++) {
            if (supportedChains[i]) {
                count++;
            }
        }

        // Create array and populate it
        uint16[] memory chains = new uint16[](count);
        uint256 index = 0;
        for (uint16 i = 0; i < 1000; i++) {
            if (supportedChains[i]) {
                chains[index] = i;
                index++;
            }
        }

        return chains;
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedAssets(
        uint16
    ) external pure override returns (address[] memory) {
        // This is a simplified implementation for mock purposes
        // In a real implementation, you would need to track and return all supported assets
        address[] memory assets = new address[](1);
        assets[0] = address(0x1); // Placeholder
        return assets;
    }

    function supportsChain(
        uint16 chainId
    ) external view override returns (bool) {
        return supportedChains[chainId];
    }

    function supportsAsset(
        uint16 chainId,
        address asset
    ) external view override returns (bool) {
        return supportedAssets[chainId][asset];
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

    /// @inheritdoc IBridgeAdapter
    function supportsAssetTransfer() external pure returns (bool) {
        // Mock adapter supports asset transfers for testing
        return true;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsMessaging() external pure returns (bool) {
        // Mock adapter supports messaging for testing
        return true;
    }

    /// @inheritdoc IBridgeAdapter
    function supportsStateRead() external pure returns (bool) {
        // Mock adapter supports state reads for testing
        return true;
    }

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
}
