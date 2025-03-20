// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {IBridgeRouter} from "../../src/interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract MockAdapter is IBridgeAdapter {
    address public bridgeRouter;

    // Add a fee multiplier state variable with a default value of 100 (100%)
    uint256 public feeMultiplier = 100;

    // Add mappings to track supported chains and assets
    mapping(uint16 => bool) public supportedChains;
    mapping(uint16 => mapping(address => bool)) public supportedAssets;

    // Add mapping to track transfer statuses
    mapping(bytes32 => BridgeTypes.TransferStatus) public transferStatuses;

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

    /// @inheritdoc IBridgeAdapter
    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        uint256,
        bytes calldata
    ) external payable override returns (bytes32) {
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

    /// @inheritdoc IBridgeAdapter
    function readState(
        uint16 sourceChainId,
        address sourceContract,
        bytes4 selector,
        bytes calldata params,
        uint256,
        bytes calldata
    ) external payable override returns (bytes32) {
        // Simple mock implementation
        return
            keccak256(
                abi.encode(sourceChainId, sourceContract, selector, params)
            );
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16,
        address,
        uint256,
        uint256 gasLimit,
        bytes calldata
    ) external view override returns (uint256 nativeFee, uint256 tokenFee) {
        // Mock fee calculation - apply the fee multiplier
        nativeFee = (gasLimit * 2 gwei * feeMultiplier) / 100;
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
}
