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

    /// @notice Default calldata size for lzRead operations (1KB)
    uint32 private constant DEFAULT_CALLDATA_SIZE = 1024;

    /**
     * @notice Calculates the appropriate gas limit ensuring minimum requirements
     * @param optionsGasLimit Gas limit from options
     * @param minGasLimit Minimum gas limit to enforce
     * @return gasLimit The calculated gas limit
     */
    function _calculateGasLimit(
        uint64 optionsGasLimit,
        uint128 minGasLimit
    ) private pure returns (uint128 gasLimit) {
        return
            optionsGasLimit < minGasLimit
                ? minGasLimit
                : uint128(optionsGasLimit);
    }

    /**
     * @notice Creates or retrieves existing LayerZero options
     * @param options Bridge options containing existing options
     * @return lzOptions The LayerZero options bytes
     */
    function _createLzOptions(
        BridgeTypes.BridgeOptions memory options
    ) private pure returns (bytes memory lzOptions) {
        if (options.options.length > 0) {
            return options.options;
        } else {
            return OptionsBuilder.newOptions();
        }
    }

    /**
     * @notice Calculates the appropriate calldata size for lzRead operations
     * @param optionsCalldataSize Calldata size from options
     * @return calldataSize The calculated calldata size
     */
    function _calculateCalldataSize(
        uint32 optionsCalldataSize
    ) private pure returns (uint32 calldataSize) {
        return
            optionsCalldataSize > 0
                ? optionsCalldataSize
                : DEFAULT_CALLDATA_SIZE;
    }

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
        uint128 gasLimit = _calculateGasLimit(options.gasLimit, minGasLimit);
        bytes memory lzOptions = _createLzOptions(options);

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
        uint128 gasLimit = _calculateGasLimit(options.gasLimit, minGasLimit);
        bytes memory lzOptions = _createLzOptions(options);
        uint32 calldataSize = _calculateCalldataSize(options.calldataSize);

        return
            OptionsBuilder.addExecutorLzReadOption(
                lzOptions,
                gasLimit,
                calldataSize,
                options.msgValue
            );
    }
}
