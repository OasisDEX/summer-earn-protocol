// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ICrossChainReceiver
 * @notice Interface for contracts that receive both assets and messages from other chains
 * @dev This interface enables contracts to receive cross-chain asset transfers accompanied
 *      by arbitrary message data through the bridge system. Both assets and messages are
 *      delivered atomically via the BridgeRouter after being processed by bridge adapters.
 *
 *      Key Features:
 *      - Atomic receipt of assets and messages in a single transaction
 *      - Access to transfer metadata (operation ID, originator, source chain)
 *      - Asset validation through structured parameters
 *      - ERC165 interface detection support
 *
 *      Use Cases:
 *      - Cross-chain deposits with instruction data
 *      - Asset bridging with metadata
 *      - Cross-chain payments with context
 *      - Multi-step operations requiring both assets and data
 *
 *      Security Considerations:
 *      - Only the BridgeRouter can call receiveOperation(BridgeTypes.OperationType.TRANSFER_ASSET,abi.encode(()
 *      - Implementations should validate the sourceChainId against expected chains
 *      - Implementations should validate the originator against expected senders
 *      - Asset address and amount should be validated before processing
 *      - Message content should be properly decoded and validated
 */
interface ICrossChainReceiver {
    /**
     * @notice Thrown when an invalid operation type is provided
     */
    error InvalidOperationType();
    /**
     * @notice Receives assets and an accompanying message from another chain
     * @dev Called by the BridgeRouter when a cross-chain asset transfer with message is delivered.
     *      Implementations MUST verify the caller is the authorized BridgeRouter.
     *      The assets will have already been transferred to this contract before this function is called.
     *
     * @param operationType The type of operation to perform
     * @param encodedParams The encoded parameters for the operation
     *
     * Security Requirements:
     * - MUST validate msg.sender is the authorized BridgeRouter
     * - SHOULD validate sourceChainId is from an expected/trusted chain
     * - SHOULD validate originator is an expected/trusted sender
     * - SHOULD validate asset is an expected/supported token
     * - SHOULD validate amount is within acceptable bounds
     * - MUST handle message decoding failures gracefully
     *
     * Asset Handling:
     * - Assets are transferred BEFORE this function is called
     * - Contract balance will already reflect the received amount
     * - Failed processing should handle asset recovery appropriately
     *
     * @custom:example
     * ```solidity
     * function receive(
     *     BridgeTypes.OperationType operationType,
     *     bytes calldata encodedParams
     * ) external {
     *     require(msg.sender == bridgeRouter, "Only bridge router");
     *     require(operationType == BridgeTypes.OperationType.DEPOSIT, "Invalid operation type");
     *     require(encodedParams.length > 0, "Invalid encoded params");
     *
     *     // Verify we received the expected amount
     *     require(
     *         IERC20(params.asset).balanceOf(address(this)) >= expectedBalance + params.amount,
     *         "Invalid encoded params"
     *     );
     *
     *     // Decode and process the accompanying message
     *     DepositInstruction memory instruction = abi.decode(encodedParams, (DepositInstruction));
     *     _processDepositWithInstruction(instruction);
     * }
     * ```
     */
    function receiveOperation(
        BridgeTypes.OperationType operationType,
        bytes calldata encodedParams
    ) external;

    /**
     * @notice Returns whether this contract supports the given interface
     * @dev Used for ERC165 interface detection. Implementations should return true
     *      for ICrossChainReceiver interface ID.
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
