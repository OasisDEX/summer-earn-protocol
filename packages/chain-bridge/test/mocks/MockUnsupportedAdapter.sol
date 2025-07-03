// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title MockUnsupportedAdapter
 * @notice Mock adapter that doesn't support transfer operations for testing failure scenarios
 * @dev This adapter is used to test error handling when an adapter doesn't support required operations
 */
contract MockUnsupportedAdapter is ISendAdapter, IBridgeAdapter {
    function transferAsset(
        bytes32 /* operationId */,
        uint16 /* destinationChainId */,
        address /* asset */,
        address /* recipient */,
        uint256 /* amount */,
        address /* originator */,
        address /* refundAddress */,
        bytes calldata /* message */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Transfer not supported");
    }

    function sendMessage(
        bytes32 /* operationId */,
        uint16 /* destinationChainId */,
        address /* recipient */,
        bytes calldata /* message */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function readState(
        bytes32 /* operationId */,
        uint16 /* srcChainId */,
        uint16 /* dstChainId */,
        address /* dstContract */,
        bytes4 /* selector */,
        bytes calldata /* readParams */,
        address /* refundAddress */,
        BridgeTypes.AdapterParams calldata /* adapterParams */
    ) external payable {
        revert("Not implemented");
    }

    function estimateFee(
        uint16 /* destinationChainId */,
        address /* asset */,
        uint256 /* amount */,
        BridgeTypes.AdapterParams calldata /* adapterParams */,
        BridgeTypes.OperationType /* operationType */
    ) external pure returns (uint256 nativeFee, uint256 tokenFee) {
        nativeFee = 0.01 ether;
        tokenFee = 0;
    }

    function getOperationStatus(
        bytes32 /* operationId */
    ) external pure returns (BridgeTypes.OperationStatus) {
        return BridgeTypes.OperationStatus.SENT;
    }

    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 8453;
        return chains;
    }

    function supportsChain(uint16 /* chainId */) external pure returns (bool) {
        return true;
    }

    function supportsOperation(
        BridgeTypes.OperationType /* operationType */
    ) external pure returns (bool) {
        return false; // Doesn't support any operations
    }

    function setBridgeRouter(address /* newBridgeRouter */) external {
        // No-op for mock
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure returns (bool) {
        return
            interfaceId == type(ISendAdapter).interfaceId ||
            interfaceId == type(IBridgeAdapter).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
