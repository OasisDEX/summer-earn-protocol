// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title BridgeTypes
 * @notice Library of types used by the bridge contracts
 */
library BridgeTypes {
    /**
     * @notice Status of a cross-chain transfer
     */
    enum OperationStatus {
        SENT, // Operation has been sent to the destination chain
        FAILED // Operation has failed
    }

    /**
     * @notice Bridge options structure
     * @dev This struct is used to pass options to the bridge.
     * @dev The specifiedAdapter is the address of the adapter to use.
     * @dev The gasLimit is the gas limit for execution on destination chain.
     * @dev The calldataSize is the size of expected return calldata (for read operations).
     * @dev The msgValue is the native value to forward (for operations requiring value).
     * @dev The options are additional adapter-specific parameters.
     */
    struct BridgeOptions {
        address specifiedAdapter; // Required specific adapter to use (address(0) will revert)
        uint64 gasLimit; // Gas limit for execution on destination chain
        uint32 calldataSize; // Size of expected return calldata (for read operations)
        uint128 msgValue; // Native value to forward (for operations requiring value)
        bytes options; // Additional adapter-specific parameters
    }

    // Enum for operation types
    enum OperationType {
        MESSAGE,
        READ_STATE,
        TRANSFER_ASSET
    }

    /**
     * @notice Parameters for executeTransferAssets
     * @dev This struct is used to transfer assets from one chain to another.
     * @dev The originator is the address that initiated the transfer ie. crosschain ark
     * @dev The target is the address that will receive the assets.
     * @dev The asset is the address of the asset to be transferred.
     * @dev The amount is the amount of the asset to be transferred.
     * @dev The message is the message to be sent to the destination chain.
     * @dev The refundAddress is the address that will receive the refund.
     */
    struct ExecuteTransferParams {
        address originator;
        uint16 destinationChainId;
        address target;
        address asset;
        uint256 amount;
        bytes message;
        address refundAddress;
    }

    /**
     * @notice Parameters for executeReadState
     * @dev This struct is used to read state from a contract on a destination chain.
     * @dev The originator is the address that initiated the read state operation ie. crosschain ark
     * @dev The destinationChainId is the chain id of the destination chain.
     * @dev The target is the address that will be read from.
     * @dev The selector is the selector of the function to read state from.
     * @dev The readParams are the parameters to pass to the read state function.
     * @dev The refundAddress is the address that will receive the refund.
     */
    struct ExecuteReadStateParams {
        address originator;
        uint16 destinationChainId;
        address target;
        bytes4 selector;
        bytes readParams;
        address refundAddress;
    }

    /**
     * @notice Parameters for executeSendMessage
     * @dev This struct is used to send a message to a destination chain.
     * @dev The originator is the address that initiated the send message operation ie. crosschain ark
     * @dev The destinationChainId is the chain id of the destination chain.
     * @dev The target is the address that will receive the message.
     * @dev The message is the message to be sent to the destination chain.
     * @dev The refundAddress is the address that will receive the refund.
     */
    struct ExecuteSendMessageParams {
        address originator;
        uint16 destinationChainId;
        address target;
        bytes message;
        address refundAddress;
    }

    /**
     * @notice Generic wrapper for a cross-chain state–read response
     * @dev Keeps result bytes in a typed container so every contract
     *      that consumes the response can simply:
     *          BridgeTypes.ReadResponse memory r =
     *              abi.decode(resultData, (BridgeTypes.ReadResponse));
     *      and then decode `r.data` to whatever concrete type it expects.
     */
    struct RelayedReadResponse {
        bytes readResponseData; // ABI-encoded return data of the read call
        bytes32 operationId;
        uint16 sourceChainId;
    }
    struct RelayedTransferParams {
        bytes32 operationId;
        address originator;
        uint16 sourceChainId;
        address recipient;
        address asset;
        uint256 amount;
        bytes message;
    }
    struct RelayedMessageParams {
        bytes32 operationId;
        address originator;
        uint16 sourceChainId;
        address recipient;
        bytes message;
    }

    struct DeliverPayload {
        bytes32 operationId; // cross-chain operation ID
        address originator; // original msg.sender on the source chain
        address sourceAsset; // token the user supplied on the source chain
    }
}
