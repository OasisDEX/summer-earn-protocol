// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";

/**
 * @title BridgeOptionsTestHelper
 * @notice Helper library for creating BridgeOptions in tests with sensible defaults
 * @dev This reduces boilerplate code across test files and ensures consistency
 */
library BridgeOptionsTestHelper {
    uint64 public constant DEFAULT_GAS_LIMIT = 500000;
    uint32 public constant DEFAULT_CALLDATA_SIZE = 0;
    uint128 public constant DEFAULT_MSG_VALUE = 0;
    bytes public constant DEFAULT_OPTIONS = "";

    /**
     * @notice Creates BridgeOptions with sensible defaults
     * @param specifiedAdapter The adapter address to use
     * @return options BridgeOptions struct with default values
     */
    function defaultOptions(
        address specifiedAdapter
    ) internal pure returns (BridgeTypes.BridgeOptions memory) {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: specifiedAdapter,
                gasLimit: DEFAULT_GAS_LIMIT,
                calldataSize: DEFAULT_CALLDATA_SIZE,
                msgValue: DEFAULT_MSG_VALUE,
                options: DEFAULT_OPTIONS
            });
    }

    /**
     * @notice Creates BridgeOptions with custom gas limit
     * @param specifiedAdapter The adapter address to use
     * @param gasLimit Custom gas limit
     * @return options BridgeOptions struct with custom gas limit
     */
    function withGasLimit(
        address specifiedAdapter,
        uint64 gasLimit
    ) internal pure returns (BridgeTypes.BridgeOptions memory) {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: specifiedAdapter,
                gasLimit: gasLimit,
                calldataSize: DEFAULT_CALLDATA_SIZE,
                msgValue: DEFAULT_MSG_VALUE,
                options: DEFAULT_OPTIONS
            });
    }

    /**
     * @notice Creates BridgeOptions with no adapter (for testing failures)
     * @return options BridgeOptions struct with zero address adapter
     */
    function noAdapter()
        internal
        pure
        returns (BridgeTypes.BridgeOptions memory)
    {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: address(0),
                gasLimit: DEFAULT_GAS_LIMIT,
                calldataSize: DEFAULT_CALLDATA_SIZE,
                msgValue: DEFAULT_MSG_VALUE,
                options: DEFAULT_OPTIONS
            });
    }

    /**
     * @notice Creates fully customizable BridgeOptions
     * @param specifiedAdapter The adapter address to use
     * @param gasLimit Custom gas limit
     * @param calldataSize Custom calldata size
     * @param msgValue Custom msg.value requirement
     * @param options Custom adapter-specific options
     * @return bridgeOptions Fully customized BridgeOptions struct
     */
    function custom(
        address specifiedAdapter,
        uint64 gasLimit,
        uint32 calldataSize,
        uint128 msgValue,
        bytes memory options
    ) internal pure returns (BridgeTypes.BridgeOptions memory bridgeOptions) {
        return
            BridgeTypes.BridgeOptions({
                specifiedAdapter: specifiedAdapter,
                gasLimit: gasLimit,
                calldataSize: calldataSize,
                msgValue: msgValue,
                options: options
            });
    }
}
