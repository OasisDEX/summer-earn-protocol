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
    enum OperationStatus {
        QUEUED, // Only used in BridgeQueue
        SENT, // Operation has been sent to the destination chain
        FAILED // Operation has failed
    }

    /**
     * @notice Generic adapter options structure for cross-chain operations
     */
    struct AdapterParams {
        uint64 gasLimit; // Gas limit for execution on destination chain
        uint32 calldataSize; // Size of expected return calldata (for read operations)
        uint128 msgValue; // Native value to forward (for operations requiring value)
        bytes options; // Additional adapter-specific parameters
    }

    /**
     * @notice Bridge options structure
     */
    struct BridgeOptions {
        address specifiedAdapter; // Required specific adapter to use (address(0) will revert)
        AdapterParams adapterParams; // Generic adapter options
    }

    // Add a new enum for operation types
    enum OperationType {
        MESSAGE,
        READ_STATE,
        TRANSFER_ASSET
    }

    /**
     * @notice Parameters for executeTransferAssets
     */
    struct ExecuteTransferParams {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address recipient;
        address originator;
        address keeper; // Add keeper field for refunds
        BridgeOptions options;
    }

    /**
     * @notice Parameters for executeReadState
     */
    struct ExecuteReadStateParams {
        uint16 dstChainId;
        address dstContract;
        bytes4 selector;
        bytes readParams;
        address originator;
        address keeper; // Add keeper field for refunds
        BridgeOptions options;
    }

    /**
     * @notice Parameters for executeSendMessage
     */
    struct ExecuteSendMessageParams {
        uint16 destinationChainId;
        address recipient;
        bytes message;
        address originator;
        address keeper; // Add keeper field for refunds
        BridgeOptions options;
    }
}
