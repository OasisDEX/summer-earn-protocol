// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title LayerZeroOptionsHelper
 * @notice Helper library for standardizing LayerZero options creation
 * @dev Provides consistent methods for creating options for different LayerZero operations
 */
library LayerZeroOptionsHelper {
    using OptionsBuilder for bytes;

    // Option types
    uint8 internal constant OPTION_TYPE_EXECUTOR = 1;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    /**
     * @notice Creates standard messaging options with appropriate gas limit
     * @param adapterParams Additional adapter params (optional)
     * @param minGasLimit Minimum gas limit to enforce (if adapter param gas limit is lower)
     * @return Options bytes formatted for LayerZero standard messaging
     */
    function createMessagingOptions(
        BridgeTypes.AdapterParams memory adapterParams,
        uint128 minGasLimit
    ) internal pure returns (bytes memory) {
        bytes memory options;

        // Ensure gas limit meets minimum requirements
        uint128 gasLimit = adapterParams.gasLimit < minGasLimit
            ? minGasLimit
            : adapterParams.gasLimit;

        // Use provided msgValue
        uint128 msgValue = adapterParams.msgValue;

        // Start with user-provided options or create new empty options
        if (adapterParams.options.length > 0) {
            // Use the user's options as the base if provided
            options = adapterParams.options;
        } else {
            // Create new empty options if none provided
            options = OptionsBuilder.newOptions();
        }

        // Add our LzReceive option to the existing or new options
        return
            OptionsBuilder.addExecutorLzReceiveOption(
                options,
                gasLimit,
                msgValue
            );
    }

    /**
     * @notice Creates lzRead options with appropriate gas limit and calldata size
     * @param adapterParams Additional adapter params (optional)
     * @param minGasLimit Minimum gas limit to enforce (if adapter param gas limit is lower)
     * @return Options bytes formatted for LayerZero lzRead operations
     */
    function createLzReadOptions(
        BridgeTypes.AdapterParams memory adapterParams,
        uint128 minGasLimit
    ) internal pure returns (bytes memory) {
        bytes memory options;

        // Ensure gas limit meets minimum requirements
        uint128 gasLimit = adapterParams.gasLimit < minGasLimit
            ? minGasLimit
            : adapterParams.gasLimit;

        // Start with user-provided options or create new empty options
        if (adapterParams.options.length > 0) {
            // Use the user's options as the base if provided
            options = adapterParams.options;
        } else {
            // Create new empty options if none provided
            options = OptionsBuilder.newOptions();
        }

        // Add our LzRead option to the existing or new options
        return
            OptionsBuilder.addExecutorLzReadOption(
                options,
                gasLimit,
                adapterParams.calldataSize,
                adapterParams.msgValue
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
