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
     * @notice Options structure for LayerZero operations
     */
    struct LayerZeroOptions {
        uint8 optionType; // Type of LayerZero option (standard, read, etc.)
        uint64 gasLimit; // Gas limit for execution
        uint64 calldataSize; // Size of expected return calldata (for lzRead)
        uint128 msgValue; // Native value to forward (for lzRead with msgValue)
        bytes adapterParams; // Additional adapter-specific parameters
    }

    /**
     * @notice Bridge options structure
     */
    struct BridgeOptions {
        address specifiedAdapter;
        uint8 bridgePreference;
        LayerZeroOptions lzOptions;
    }
}
