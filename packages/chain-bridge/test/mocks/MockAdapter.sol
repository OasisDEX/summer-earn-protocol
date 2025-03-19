// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgeAdapter} from "../../src/adapters/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

contract MockAdapter is IBridgeAdapter {
    address public bridgeRouter;
    mapping(bytes32 => BridgeTypes.TransferStatus) public transferStatuses;
    mapping(uint16 => bool) public supportedChains;
    mapping(uint16 => mapping(address => bool)) public supportedAssets;

    constructor(address _bridgeRouter) {
        bridgeRouter = _bridgeRouter;
    }

    function transferAsset(
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external payable override returns (bytes32 transferId) {
        // Simple mock implementation
        transferId = keccak256(
            abi.encodePacked(destinationChainId, asset, recipient, amount)
        );
        transferStatuses[transferId] = BridgeTypes.TransferStatus.PENDING;
        return transferId;
    }

    function estimateFee(
        uint16 destinationChainId,
        address asset,
        uint256 amount,
        uint256 gasLimit,
        bytes calldata adapterParams
    ) external view override returns (uint256 nativeFee, uint256 tokenFee) {
        // Mock implementation
        return (0.01 ether, 0);
    }

    function getTransferStatus(
        bytes32 transferId
    ) external view override returns (BridgeTypes.TransferStatus) {
        return transferStatuses[transferId];
    }

    function getSupportedChains()
        external
        view
        override
        returns (uint16[] memory)
    {
        // Mock implementation
        uint16[] memory chains = new uint16[](1);
        chains[0] = 1;
        return chains;
    }

    function getSupportedAssets(
        uint16 chainId
    ) external view override returns (address[] memory) {
        // Mock implementation
        address[] memory assets = new address[](0);
        return assets;
    }

    // Functions for test setup
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

    function setTransferStatus(
        bytes32 transferId,
        BridgeTypes.TransferStatus status
    ) external {
        transferStatuses[transferId] = status;
    }
}
