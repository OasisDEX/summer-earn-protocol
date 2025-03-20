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
     * @notice Options for a bridge transfer
     */
    struct BridgeOptions {
        address feeToken; // Token to pay fees with (address(0) for native)
        uint8 bridgePreference; // 0: lowest cost, 1: fastest, 2: most secure
        uint256 gasLimit; // Gas limit for execution on destination
        address refundAddress; // Address to refund excess fees
        bytes adapterParams; // Bridge-specific parameters
        address specifiedAdapter; // Explicitly specified adapter (or address(0) for auto-selection)
    }
}
