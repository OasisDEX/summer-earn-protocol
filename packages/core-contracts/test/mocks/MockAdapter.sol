// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "@summerfi/chain-bridge/libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "@summerfi/chain-bridge/interfaces/IBridgeAdapter.sol";
import {IBridgeRouter} from "@summerfi/chain-bridge/interfaces/IBridgeRouter.sol";

/**
 * @title MockAdapter
 * @notice Mock implementation of a bridge adapter for testing purposes
 */
contract MockAdapter is IBridgeAdapter {
    // Address of the bridge router
    address public immutable bridgeRouter;

    // Track received messages
    struct ReceivedMessage {
        bytes message;
        address sender;
        uint16 sourceChainId;
        bytes32 messageId;
    }

    ReceivedMessage[] public receivedMessages;

    // Events
    event MessageRelayed(
        bytes32 messageId,
        address recipient,
        uint16 sourceChainId
    );

    constructor(address _bridgeRouter) {
        bridgeRouter = _bridgeRouter;
    }

    // Function to simulate receiving a message from another chain
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

    // Mock implementations of required interface functions

    function transferAsset(
        uint16,
        address,
        address,
        uint256,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert("Not implemented");
    }

    function readState(
        uint16,
        uint16,
        address,
        bytes4,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert("Not implemented");
    }

    function sendMessage(
        uint16,
        address,
        bytes calldata,
        address,
        BridgeTypes.AdapterParams calldata
    ) external payable returns (bytes32) {
        revert("Not implemented");
    }

    function estimateFee(
        uint16,
        address,
        uint256,
        BridgeTypes.AdapterParams calldata,
        BridgeTypes.OperationType
    ) external pure returns (uint256, uint256) {
        return (0, 0);
    }

    function getOperationStatus(
        bytes32
    ) external pure returns (BridgeTypes.OperationStatus) {
        return BridgeTypes.OperationStatus.PENDING;
    }

    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 111; // SOURCE_CHAIN_ID from tests
        return chains;
    }

    function getSupportedAssets(
        uint16
    ) external pure returns (address[] memory) {
        address[] memory assets = new address[](1);
        assets[0] = address(0);
        return assets;
    }

    function supportsChain(uint16) external pure returns (bool) {
        return true;
    }

    function supportsAsset(uint16, address) external pure returns (bool) {
        return true;
    }

    function supportsAssetTransfer() external pure returns (bool) {
        return true;
    }

    function supportsStateRead() external pure returns (bool) {
        return true;
    }

    function supportsMessaging() external pure returns (bool) {
        return true;
    }
}
