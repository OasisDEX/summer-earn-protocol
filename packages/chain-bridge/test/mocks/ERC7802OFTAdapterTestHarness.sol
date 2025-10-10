// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC7802OFTAdapter} from "../../src/adapters/ERC7802OFTAdapter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

/**
 * @title ERC7802OFTAdapterTestHarness
 * @notice Test harness that exposes internal functions for testing
 */
contract ERC7802OFTAdapterTestHarness is ERC7802OFTAdapter {
    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint
    ) ERC7802OFTAdapter(_crossChainRegistry, _accessManager, _lzEndpoint) {}

    /**
     * @notice Public wrapper to expose _decodeOFTCompose for testing
     */
    function decodeOFTCompose_test(
        bytes calldata message
    )
        public
        view
        returns (
            uint32 srcEid,
            uint256 amountLD,
            address composeFrom,
            bytes memory composeMsg
        )
    {
        return _decodeOFTCompose(message);
    }

    /**
     * @notice Public wrapper to expose _encodeComposeTransferParams for testing
     */
    function encodeComposeTransferParams_test(
        bytes32 operationId,
        BridgeTypes.ExecuteTransferParams calldata params
    ) public view returns (bytes memory) {
        return _encodeComposeTransferParams(operationId, params);
    }

    /**
     * @notice Public wrapper to expose _sendTransport for testing
     */
    function sendTransport_test(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.ExecuteTransferParams calldata params,
        address refundAddress
    ) public payable returns (uint256 feeUsed) {
        return
            _sendTransport(
                operationId,
                token,
                dstChainId,
                dstAdapter,
                amount,
                options,
                params,
                refundAddress
            );
    }

    /**
     * @notice Public wrapper to expose _estimateTransport for testing
     */
    function estimateTransport_test(
        bytes32 operationId,
        address token,
        uint16 dstChainId,
        address dstAdapter,
        uint256 amount,
        BridgeTypes.BridgeOptions calldata options,
        BridgeTypes.ExecuteTransferParams calldata params
    ) public view returns (uint256 nativeFee, uint256 tokenFee) {
        return
            _estimateTransport(
                operationId,
                token,
                dstChainId,
                dstAdapter,
                amount,
                options,
                params
            );
    }
}
