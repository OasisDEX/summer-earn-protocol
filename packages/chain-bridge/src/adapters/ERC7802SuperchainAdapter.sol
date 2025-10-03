// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {BaseERC7802Adapter} from "./BaseERC7802Adapter.sol";
import {ISuperchainTokenBridge} from "../interfaces/ISuperchainTokenBridge.sol";

/**
 * @title ERC7802SuperchainAdapter
 * @notice ERC-7802 adapter using OP Superchain Token Bridge predeploy
 * @dev See: https://docs.optimism.io/interop/superchain-erc20
 */
contract ERC7802SuperchainAdapter is BaseERC7802Adapter {
    ISuperchainTokenBridge public immutable superchainBridge;

    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint,
        address _superchainBridge
    ) BaseERC7802Adapter(_crossChainRegistry, _accessManager, _lzEndpoint) {
        if (_superchainBridge == address(0)) revert InvalidParams();
        superchainBridge = ISuperchainTokenBridge(_superchainBridge);
    }

    function _sendTransport(
        bytes32,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata,
        address
    ) internal override returns (uint256 feeUsed) {
        superchainBridge.sendERC20(
            token,
            _externalOrCanonical(dstChainId),
            dstAdapter,
            amount
        );
        return 0; // initiation is a regular L2 tx; autorelayer handles execution
    }

    function _estimateTransport(
        bytes32,
        address,
        uint16,
        address,
        uint256,
        BridgeTypes.BridgeOptions calldata,
        BridgeTypes.ExecuteTransferParams calldata
    ) internal view override returns (uint256 nativeFee, uint256 tokenFee) {
        return (0, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        MESSAGE ADAPTER IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Read state from a contract on a source chain (not supported by Superchain adapter)
    function readState(
        bytes32,
        BridgeTypes.ExecuteReadStateParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Send a message to a destination chain (not supported by Superchain adapter)
    function sendMessage(
        bytes32,
        BridgeTypes.ExecuteSendMessageParams calldata,
        BridgeTypes.BridgeOptions calldata
    ) external payable {
        revert OperationNotSupported();
    }

    /// @notice Check if the adapter supports a specific message operation type
    function supportsMessageOperation(
        uint16,
        BridgeTypes.OperationType operationType
    ) external pure returns (bool) {
        return operationType == BridgeTypes.OperationType.TRANSFER_ASSET;
    }
}
