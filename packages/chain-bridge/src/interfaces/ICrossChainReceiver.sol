// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title ICrossChainReceiver
 * @notice Unified interface for receiving cross-chain operations
 * @dev Replaces the separate ICrossChainAssetReceiver, ICrossChainMessageReceiver, and ICrossChainStateReadReceiver interfaces
 */
interface ICrossChainReceiver is IERC165 {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a cross-chain operation is successfully processed
    event CrossChainOperationReceived(
        BridgeTypes.OperationType indexed operationType,
        bytes32 indexed operationId,
        uint16 indexed sourceChainId
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an unsupported operation type is received
    error UnsupportedOperationType();

    /// @notice Thrown when the caller is not authorized to deliver operations
    error Unauthorized();

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Receives and processes a cross-chain operation
     * @param operationType The type of operation being delivered
     * @param encodedParams Encoded operation parameters specific to the operation type
     * @dev This is the unified entry point for all cross-chain operations
     * @dev The implementation should decode encodedParams based on operationType:
     *      - MESSAGE: BridgeTypes.RelayedMessageParams
     *      - TRANSFER_ASSET: BridgeTypes.RelayedTransferParams
     *      - READ_STATE: BridgeTypes.RelayedReadResponse
     */
    function receiveOperation(
        BridgeTypes.OperationType operationType,
        bytes calldata encodedParams
    ) external;

    /**
     * @notice Returns the operation types supported by this receiver
     * @return supportedTypes Array of supported operation types
     * @dev This allows callers to discover what operations this receiver can handle
     */
    function getSupportedOperationTypes()
        external
        view
        returns (BridgeTypes.OperationType[] memory supportedTypes);
}
