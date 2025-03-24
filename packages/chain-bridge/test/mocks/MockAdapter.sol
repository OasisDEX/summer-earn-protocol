// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IReceiveAdapter} from "../../src/interfaces/IReceiveAdapter.sol";
import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";

contract MockAdapter is IBridgeAdapter {
    address public bridgeRouter;

    // Add a fee multiplier state variable with a default value of 100 (100%)
    uint256 public feeMultiplier = 100;

    // Add mappings to track supported chains and assets
    mapping(uint16 => bool) public supportedChains;
    mapping(uint16 => mapping(address => bool)) public supportedAssets;

    // Add mapping to track transfer statuses
    mapping(bytes32 => BridgeTypes.TransferStatus) public transferStatuses;

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

    constructor(address _bridgeRouter) {
        bridgeRouter = _bridgeRouter;
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
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        // Generate a deterministic transfer ID for testing purposes
        bytes32 transferId = keccak256(
            abi.encode(
                destinationChainId,
                asset,
                recipient,
                amount,
                block.timestamp
            )
        );

        // Mark transfer as pending
        transferStatuses[transferId] = BridgeTypes.TransferStatus.PENDING;

        // Return the transfer ID
        return transferId;
    }

    /// @inheritdoc ISendAdapter
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        // Simple mock implementation
        return
            keccak256(
                abi.encode(sourceChainId, sourceContract, selector, params)
            );
    }

    /// @inheritdoc ISendAdapter
    function requestAssetTransfer(
        address asset,
        uint256 amount,
        address sender,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external payable override {
        // Store the parameters for verification in tests
        lastReceivedAsset = asset;
        lastReceivedAmount = amount;
        lastReceivedSender = sender;
        lastReceivedChainId = sourceChainId;
        lastReceivedRequestId = transferId;
        lastReceivedExtraData = extraData;

        // Mark transfer as pending
        transferStatuses[transferId] = BridgeTypes.TransferStatus.PENDING;
    }

    /// @inheritdoc IReceiveAdapter
    function receiveAssetTransfer(
        address asset,
        uint256 amount,
        address recipient,
        uint16 sourceChainId,
        bytes32 transferId,
        bytes calldata extraData
    ) external override {
        // Store the parameters for verification in tests
        lastReceivedAsset = asset;
        lastReceivedAmount = amount;
        lastReceivedRecipient = recipient;
        lastReceivedChainId = sourceChainId;
        lastReceivedRequestId = transferId;
        lastReceivedExtraData = extraData;

        // Mark transfer as completed
        transferStatuses[transferId] = BridgeTypes.TransferStatus.COMPLETED;
    }

    /// @inheritdoc IReceiveAdapter
    function receiveMessage(
        bytes calldata message,
        address recipient,
        uint16 sourceChainId,
        bytes32 messageId
    ) external override {
        // Store the received data for validation in tests
        lastReceivedResponse = message;
        lastReceivedRecipient = recipient;
        lastReceivedChainId = sourceChainId;
        lastReceivedRequestId = messageId;
    }

    /// @inheritdoc IReceiveAdapter
    function receiveStateRead(
        bytes calldata resultData,
        address requestor,
        uint16 sourceChainId,
        bytes32 requestId
    ) external override {
        // Store the received data for validation in tests
        lastReceivedResponse = resultData;
        lastReceivedSender = requestor;
        lastReceivedChainId = sourceChainId;
        lastReceivedRequestId = requestId;
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external view returns (uint256 nativeFee, uint256 tokenFee) {
        // Mock fee calculation - apply the fee multiplier
        nativeFee = (adapterParams.gasLimit * 2 gwei * feeMultiplier) / 100;
        tokenFee = 0; // No token fee in this mock

        return (nativeFee, tokenFee);
    }

    /// @inheritdoc IBridgeAdapter
    function getTransferStatus(
        bytes32 transferId
    ) external view override returns (BridgeTypes.TransferStatus) {
        return transferStatuses[transferId];
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

    function getAdapterType() external pure override returns (uint8) {
        // Return a type value for mock adapter (e.g., 0 for mock)
        return 0;
    }

    /// @inheritdoc ISendAdapter
    function composeActions(
        uint16 destinationChainId,
        bytes[] calldata actions,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable returns (bytes32) {
        // Check if chain is supported
        require(supportedChains[destinationChainId], "Chain not supported");

        // Generate a deterministic transfer ID for testing purposes
        bytes32 transferId = keccak256(
            abi.encode(
                destinationChainId,
                actions,
                adapterParams.gasLimit,
                block.timestamp
            )
        );

        // Store message details for verification in tests
        lastReceivedChainId = destinationChainId;
        lastReceivedRequestId = transferId;
        lastReceivedExtraData = abi.encode(actions);

        // Mark transfer as pending
        transferStatuses[transferId] = BridgeTypes.TransferStatus.PENDING;

        // Emit event for testing purposes
        emit ActionComposed(transferId, destinationChainId, actions.length);

        return transferId;
    }

    // Add an event for composed actions
    event ActionComposed(
        bytes32 indexed transferId,
        uint16 destinationChainId,
        uint256 actionCount
    );
}
