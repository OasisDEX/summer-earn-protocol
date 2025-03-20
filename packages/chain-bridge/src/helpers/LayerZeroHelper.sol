// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title LayerZeroHelper
 * @notice Helper library for standardizing LayerZero options creation
 * @dev Provides consistent methods for creating options for different LayerZero operations
 */
library LayerZeroHelper {
    // Option types
    uint8 internal constant OPTION_TYPE_EXECUTOR = 1;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE = 2;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_RECEIVE_NATIVE = 3;
    uint8 internal constant OPTION_TYPE_EXECUTOR_LZ_READ = 7;

    /**
     * @notice Creates standard messaging options with appropriate gas limit
     * @param gasLimit Gas limit for execution
     * @param adapterParams Additional adapter params (optional)
     * @return Options bytes formatted for LayerZero standard messaging
     */
    function createMessagingOptions(
        uint64 gasLimit,
        bytes memory adapterParams
    ) internal pure returns (bytes memory) {
        // Start with version 1 and option type for standard execution
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint8(OPTION_TYPE_EXECUTOR_LZ_RECEIVE), // option type
            gasLimit // gas limit as uint64
        );

        // Append additional params if provided
        if (adapterParams.length > 0) {
            options = bytes.concat(options, adapterParams);
        }

        return options;
    }

    /**
     * @notice Creates lzRead options with appropriate gas limit and calldata size
     * @param gasLimit Gas limit for execution
     * @param calldataSize Size of the expected return calldata
     * @param msgValue Native value to send with the execution (optional)
     * @param adapterParams Additional adapter params (optional)
     * @return Options bytes formatted for LayerZero lzRead operations
     */
    function createLzReadOptions(
        uint64 gasLimit,
        uint64 calldataSize,
        uint128 msgValue,
        bytes memory adapterParams
    ) internal pure returns (bytes memory) {
        // Create options for lzRead with version 1
        bytes memory options = abi.encodePacked(
            uint16(1), // version
            uint8(OPTION_TYPE_EXECUTOR_LZ_READ), // option type
            gasLimit, // gas limit as uint64
            calldataSize, // calldata size as uint64
            msgValue // msg.value as uint128
        );

        // Append additional params if provided
        if (adapterParams.length > 0) {
            options = bytes.concat(options, adapterParams);
        }

        return options;
    }

    /**
     * @notice Estimates appropriate gas limit based on operation type
     * @param isReadOperation Whether this is a read operation
     * @return Appropriate default gas limit
     */
    function getDefaultGasLimit(
        bool isReadOperation
    ) internal pure returns (uint64) {
        return isReadOperation ? 200000 : 500000;
    }
}
