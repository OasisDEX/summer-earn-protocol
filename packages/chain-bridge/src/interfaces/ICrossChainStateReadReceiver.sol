// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../libraries/BridgeTypes.sol";

/**
 * @title ICrossChainStateReadReceiver
 * @notice Interface for contracts that receive responses from cross-chain state read operations
 * @dev This interface enables contracts to receive responses to state read requests made through
 *      the bridge system. State reads allow querying data from contracts on other chains.
 *
 *      Key Features:
 *      - Receive encoded results from cross-chain function calls
 *      - Request ID tracking for matching responses to requests
 *      - Source chain validation for security
 *      - ERC165 interface detection support
 *
 *      Use Cases:
 *      - Reading token balances from other chains
 *      - Querying contract state for cross-chain coordination
 *      - Retrieving configuration data from remote contracts
 *
 *      Security Considerations:
 *      - Only the BridgeRouter should call receiveStateRead()
 *      - Implementations should validate the sourceChainId against expected chains
 *      - Request IDs should be tracked to prevent replay attacks
 *      - Result data should be properly decoded and validated
 */
interface ICrossChainStateReadReceiver {
    /**
     * @notice Receives the result of a cross-chain state read operation
     * @dev Called by the BridgeRouter when a state read response is delivered.
     *      Implementations MUST verify the caller is the authorized BridgeRouter.
     *
     * @param params Parameters containing the read response data, operation ID, and source chain ID.
     *
     * Security Requirements:
     * - MUST validate msg.sender is the authorized BridgeRouter
     * - SHOULD validate sourceChainId is from an expected/trusted chain
     * - SHOULD validate requestId matches a pending request
     * - MUST handle result decoding failures gracefully
     * - SHOULD prevent processing duplicate responses
     *
     * @custom:example
     * ```solidity
     * function receiveStateRead(
     *     bytes calldata resultData,
     *     bytes32 requestId,
     *     uint16 sourceChainId
     * ) external {
     *     require(msg.sender == bridgeRouter, "Only bridge router");
     *     require(sourceChainId == trustedChainId, "Invalid source chain");
     *     require(pendingRequests[requestId], "Unknown request");
     *
     *     // Decode the result based on expected return type
     *     uint256 balance = abi.decode(resultData, (uint256));
     *     _processStateReadResult(requestId, balance);
     *
     *     delete pendingRequests[requestId]; // Prevent replay
     * }
     * ```
     */
    function receiveStateRead(
        BridgeTypes.DeliveredReadResponse calldata params
    ) external;

    /**
     * @notice Returns whether this contract supports the given interface
     * @dev Used for ERC165 interface detection. Implementations should return true
     *      for ICrossChainStateReadReceiver interface ID.
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
