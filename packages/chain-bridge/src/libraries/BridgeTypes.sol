// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

/**
 * @title BridgeTypes
 * @notice Library of types used by the bridge contracts
 */
library BridgeTypes {
    /**
     * @notice Status of a cross-chain transfer
     */
    enum TransferStatus {
        UNKNOWN,
        PENDING,
        DELIVERED,
        FAILED,
        COMPLETED
    }

    /**
     * @notice Generic adapter options structure for cross-chain operations
     */
    struct AdapterOptions {
        uint64 gasLimit; // Gas limit for execution on destination chain
        uint64 calldataSize; // Size of expected return calldata (for read operations)
        uint128 msgValue; // Native value to forward (for operations requiring value)
        bytes adapterParams; // Additional adapter-specific parameters
    }

    /**
     * @notice Bridge options structure
     */
    struct BridgeOptions {
        address specifiedAdapter; // Optional specific adapter to use (address(0) means auto-select)
        AdapterOptions adapterOptions; // Generic adapter options
    }
}
