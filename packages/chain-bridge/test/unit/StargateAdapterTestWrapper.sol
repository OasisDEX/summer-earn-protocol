// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {StargateAdapter} from "../../src/adapters/StargateAdapter.sol";

/**
 * @title StargateAdapterTestWrapper
 * @notice Test wrapper that exposes internal methods for testing
 */
contract StargateAdapterTestWrapper is StargateAdapter {
    constructor(
        address _crossChainRegistry,
        address _accessManager,
        address _lzEndpoint,
        address _harborCommand
    ) StargateAdapter(_crossChainRegistry, _accessManager, _lzEndpoint) {}
}
