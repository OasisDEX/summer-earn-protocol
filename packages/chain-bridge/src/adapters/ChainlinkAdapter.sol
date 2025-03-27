// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBridgeAdapter} from "../interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "../interfaces/IBridgeRouter.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {ISendAdapter} from "../interfaces/ISendAdapter.sol";

/**
 * @title ChainlinkAdapter
 * @notice Adapter for the Chainlink CCIP protocol (PLACEHOLDER IMPLEMENTATION)
 * @dev This is currently a placeholder implementation with unimplemented methods
 */
contract ChainlinkAdapter is IBridgeAdapter {
    // Chainlink specific state variables
    address public chainlinkRouter;
    address public bridgeRouter;
    mapping(bytes32 => BridgeTypes.OperationStatus) public operationStatuses;

    // Mapping of operation types to Chainlink message types
    mapping(BridgeTypes.OperationType => uint16) private operationToMessageType;

    // Chainlink receiver function
    function ccipReceive(bytes32, bytes calldata) external pure {
        // Implementation will handle incoming messages from Chainlink CCIP
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function transferAsset(
        uint16,
        address,
        address,
        uint256,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function readState(
        uint16,
        address,
        bytes4,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function getOperationStatus(
        bytes32
    ) external pure returns (BridgeTypes.OperationStatus) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedChains()
        external
        pure
        override
        returns (uint16[] memory)
    {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function getSupportedAssets(
        uint16
    ) external pure override returns (address[] memory) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType
    ) external pure returns (uint256, uint256) {
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsChain(uint16) external pure override returns (bool) {
        // This is a placeholder implementation
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAsset(
        uint16,
        address
    ) external pure override returns (bool) {
        // This is a placeholder implementation
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsAssetTransfer() external pure override returns (bool) {
        // This is a placeholder implementation
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsMessaging() external pure override returns (bool) {
        // This is a placeholder implementation
        revert OperationNotSupported();
    }

    /// @inheritdoc IBridgeAdapter
    function supportsStateRead() external pure override returns (bool) {
        // This is a placeholder implementation
        revert OperationNotSupported();
    }

    /// @inheritdoc ISendAdapter
    function sendMessage(
        uint16,
        address,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert OperationNotSupported();
    }
}
