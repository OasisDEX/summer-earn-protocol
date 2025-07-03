// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISendAdapter} from "../../src/interfaces/ISendAdapter.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title MockFleetDepositAdapter
 * @notice Mock adapter that supports transferAsset operations for fleet deposit testing
 * @dev This adapter tracks the last transferAsset call parameters for test verification
 */
contract MockFleetDepositAdapter is ISendAdapter, IBridgeAdapter {
    using SafeERC20 for IERC20;

    address public bridgeRouter;

    // Track last transferAsset call
    uint256 public lastAmount;
    address public lastAsset;
    uint16 public lastDestinationChainId;
    address public lastRecipient;
    bytes public lastMessage;
    address public lastOriginator;
    BridgeTypes.AdapterParams public lastAdapterParams;
    bytes32 public lastOperationId;

    constructor() {
        // Initialize with empty bridgeRouter, will be set later
    }

    function setBridgeRouter(address _bridgeRouter) external {
        bridgeRouter = _bridgeRouter;
    }

    function reset() external {
        lastAmount = 0;
        lastAsset = address(0);
        lastDestinationChainId = 0;
        lastRecipient = address(0);
        lastMessage = "";
        lastOriginator = address(0);
        lastOperationId = bytes32(0);
        delete lastAdapterParams;
    }

    function transferAsset(
        bytes32 operationId,
        uint16 destinationChainId,
        address asset,
        address recipient,
        uint256 amount,
        address originator,
        address /* refundAddress */,
        bytes calldata message,
        BridgeTypes.AdapterParams calldata adapterParams
    ) external payable {
        // Store the call data for verification
        lastOperationId = operationId;
        lastDestinationChainId = destinationChainId;
        lastAsset = asset;
        lastRecipient = recipient;
        lastAmount = amount;
        lastMessage = message;
        lastOriginator = originator;
        lastAdapterParams = adapterParams;

        // Transfer tokens from caller (should be BridgeRouter)
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
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
        nativeFee = 0.01 ether; // Base fee for testing
        tokenFee = 0;
    }

    function getOperationStatus(
        bytes32 /* operationId */
    ) external pure returns (BridgeTypes.OperationStatus) {
        return BridgeTypes.OperationStatus.SENT;
    }

    function getSupportedChains() external pure returns (uint16[] memory) {
        uint16[] memory chains = new uint16[](1);
        chains[0] = 8453; // Base
        return chains;
    }

    function supportsChain(uint16 /* chainId */) external pure returns (bool) {
        return true;
    }

    function supportsOperation(
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
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
