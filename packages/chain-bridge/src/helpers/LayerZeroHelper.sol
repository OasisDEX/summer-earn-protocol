// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";
/**
 * @title LayerZeroHelper
 * @notice Helper library for standardizing LayerZero options creation
 * @dev Provides consistent methods for creating options for different LayerZero operations
 */
library LayerZeroHelper {
    using OptionsBuilder for bytes;

    // Option types
    uint8 internal constant OPTION_TYPE_EXECUTOR = 1;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    /**
     * @notice Creates standard messaging options with appropriate gas limit
     * @param gasLimit Gas limit for execution
     * @param msgValue Native value to send with the execution (optional)
     * @return Options bytes formatted for LayerZero standard messaging
     */
    function createMessagingOptions(
        uint128 gasLimit,
        uint128 msgValue
    ) internal pure returns (bytes memory) {
        // Use OptionsBuilder to generate the correct option format for LayerZero v2
        return
            OptionsBuilder.newOptions().addExecutorLzReceiveOption(
                gasLimit,
                msgValue
            );
    }

    /**
     * @notice Creates lzRead options with appropriate gas limit and calldata size
     * @param gasLimit Gas limit for execution
     * @param calldataSize Size of the expected return calldata
     * @param msgValue Native value to send with the execution (optional)
     * @param adapterOptions Additional adapter params (optional)
     * @return Options bytes formatted for LayerZero lzRead operations
     */
    function createLzReadOptions(
        uint128 gasLimit,
        uint32 calldataSize,
        uint128 msgValue,
        BridgeTypes.AdapterOptions calldata adapterOptions
    ) internal pure returns (bytes memory) {
        // Use OptionsBuilder to generate the correct option format for LayerZero v2
        return
            OptionsBuilder.newOptions().addExecutorLzReadOption(
                gasLimit,
                calldataSize,
                msgValue
            );
    }

    /**
     * @notice Creates options for composed calls
     * @param index The index of the compose function call
     * @param gasLimit Gas limit for execution
     * @param msgValue Native value to send with the execution
     * @return Options bytes formatted for LayerZero lzCompose
     */
    function createComposeOptions(
        uint16 index,
        uint128 gasLimit,
        uint128 msgValue
    ) internal pure returns (bytes memory) {
        return
            OptionsBuilder.newOptions().addExecutorLzComposeOption(
                index,
                gasLimit,
                msgValue
            );
    }

    /**
     * @notice Estimates appropriate gas limit based on operation type
     * @param isReadOperation Whether this is a read operation
     * @return Appropriate default gas limit
     */
    function getDefaultGasLimit(
        bool isReadOperation
    ) internal pure returns (uint128) {
        return isReadOperation ? 200000 : 500000;
    }
}
