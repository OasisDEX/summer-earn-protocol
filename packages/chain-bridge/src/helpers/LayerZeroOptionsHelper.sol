// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

/**
 * @title LayerZeroOptionsHelper
 * @notice Helper library for standardizing LayerZero options creation
 * @dev Provides consistent methods for creating options for different LayerZero operations
 */
library LayerZeroOptionsHelper {
    using OptionsBuilder for bytes;

    /**
     * @notice Creates standard messaging options with appropriate gas limit
     * @param options Bridge options containing gas limit and other parameters
     * @param minGasLimit Minimum gas limit to enforce (if options gas limit is lower)
     * @return Options bytes formatted for LayerZero standard messaging
     */
    function createMessagingOptions(
        BridgeTypes.BridgeOptions memory options,
        uint128 minGasLimit
    ) internal pure returns (bytes memory) {
        bytes memory lzOptions;

        // Ensure gas limit meets minimum requirements
        uint128 gasLimit = options.gasLimit < minGasLimit
            ? minGasLimit
            : options.gasLimit;

        // Start with user-provided options or create new empty options
        if (options.options.length > 0) {
            // Use the user's options as the base if provided
            lzOptions = options.options;
        } else {
            // Create new empty options if none provided
            lzOptions = OptionsBuilder.newOptions();
        }

        // Add our LzReceive option to the existing or new options
        return
            OptionsBuilder.addExecutorLzReceiveOption(
                lzOptions,
                gasLimit,
                options.msgValue
            );
    }

    /**
     * @notice Creates lzRead options with appropriate gas limit and calldata size
     * @param options Bridge options containing gas limit and other parameters
     * @param minGasLimit Minimum gas limit to enforce (if options gas limit is lower)
     * @return Options bytes formatted for LayerZero lzRead operations
     */
    function createLzReadOptions(
        BridgeTypes.BridgeOptions memory options,
        uint128 minGasLimit
    ) internal pure returns (bytes memory) {
        bytes memory lzOptions;

        // Ensure gas limit meets minimum requirements
        uint128 gasLimit = options.gasLimit < minGasLimit
            ? minGasLimit
            : options.gasLimit;

        // Start with user-provided options or create new empty options
        if (options.options.length > 0) {
            lzOptions = options.options;
        } else {
            lzOptions = OptionsBuilder.newOptions();
        }

        // For lzRead operations, we need to provide a reasonable calldata size estimate
        // If not provided in options, use a default reasonable size
        uint32 calldataSize = options.calldataSize > 0
            ? uint32(options.calldataSize)
            : 1024; // Default to 1KB for read responses

        // Add our LzRead option to the existing or new options
        return
            OptionsBuilder.addExecutorLzReadOption(
                lzOptions,
                gasLimit,
                calldataSize, // ✅ Use proper calldata size (uint32)
                options.msgValue
            );
    }

    function testSkipper() public {}
}
