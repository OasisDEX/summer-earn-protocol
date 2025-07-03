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
        AdapterParams adapterParams;
    }

    // Enum for operation types
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
        bytes message;
        address originator;
        address refundAddress;
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
        address refundAddress;
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
        address refundAddress;
        BridgeOptions options;
    }

    /**
     * @notice Parameters for user-initiated fleet deposits
     */
    struct ExecuteUserFleetDepositParams {
        uint16 destinationChainId;
        address asset;
        uint256 amount;
        address fleetCommander;
        address shareRecipient;
        address originalUser;
        bytes referralCode;
        bytes message;
        BridgeTypes.BridgeOptions options;
    }

    /**
     * @notice User fleet deposit message type identifier
     * @dev Used to identify user-initiated fleet deposit compose messages in cross-chain transfers
     */
    bytes32 public constant USER_FLEET_DEPOSIT_TYPE =
        keccak256("USER_FLEET_DEPOSIT");

    /**
     * @notice Fleet deposit message data for cross-chain fleet deposits
     * @dev Used to encode/decode fleet deposit compose messages consistently
     */
    struct FleetDepositMessageData {
        /// @notice Address of the FleetCommander contract that will receive the deposit
        address fleetCommander;
        /// @notice Address that will receive the fleet shares from the deposit
        address shareRecipient;
        /// @notice Token contract address being deposited
        address asset;
        /// @notice Amount of tokens being deposited
        uint256 amount;
        /// @notice Chain ID where the deposit transaction was originally initiated
        uint256 sourceChainId;
        /// @notice Address of the user who originally initiated the cross-chain deposit transaction
        address originalUser;
        /// @notice Operation ID for the cross-chain deposit operation
        bytes32 operationId;
        /// @notice Optional referral code for tracking deposit attribution
        bytes referralCode;
    }
}
