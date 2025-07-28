// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ICrossChainMessageReceiver
 * @notice Interface for contracts that receive arbitrary messages from other chains
 * @dev This interface enables contracts to receive cross-chain messages through the bridge system.
 *      Messages are delivered via the BridgeRouter after being processed by bridge adapters.
 *
 *      Key Features:
 *      - Unified message handling with structured parameters
 *      - Access to message metadata (operation ID, originator, source chain)
 *      - ERC165 interface detection support
 *
 *      Security Considerations:
 *      - Only the BridgeRouter should call receiveMessage()
 *      - Implementations should validate the sourceChainId against expected chains
 *      - Implementations should validate the originator against expected senders
 *      - Message content should be properly decoded and validated
 */
interface ICrossChainMessageReceiver {
    /**
     * @notice Receives a cross-chain message
     * @dev Called by the BridgeRouter when a cross-chain message is delivered.
     *      Implementations MUST verify the caller is the authorized BridgeRouter.
     *
     * @param params Structured message delivery parameters containing:
     *        - operationId: Unique identifier for this cross-chain operation
     *        - originator: Address that initiated the message on the source chain
     *        - sourceChainId: Chain ID where the message originated
     *        - recipient: Address of this contract (should be address(this))
     *        - message: Encoded message payload to be processed
     *
     * Security Requirements:
     * - MUST validate msg.sender is the authorized BridgeRouter
     * - SHOULD validate sourceChainId is from an expected/trusted chain
     * - SHOULD validate originator is an expected/trusted sender
     * - MUST handle message decoding failures gracefully
     *
     * @custom:example
     * ```solidity
     * function receiveMessage(BridgeTypes.DeliveredMessageParams calldata params) external {
     *     require(msg.sender == bridgeRouter, "Only bridge router");
     *     require(params.sourceChainId == trustedChainId, "Invalid source chain");
     *
     *     // Decode and process the message
     *     MyMessageStruct memory data = abi.decode(params.message, (MyMessageStruct));
     *     _processMessage(data, params.operationId);
     * }
     * ```
     */
    function receiveMessage(
        BridgeTypes.DeliveredMessageParams calldata params
    ) external;

    /**
     * @notice Returns whether this contract supports the given interface
     * @dev Used for ERC165 interface detection. Implementations should return true
     *      for ICrossChainMessageReceiver interface ID.
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
