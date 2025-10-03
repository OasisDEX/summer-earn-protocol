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
    ) public pure returns (bytes memory) {
        return _encodeComposeTransferParams(operationId, params);
    }
}
