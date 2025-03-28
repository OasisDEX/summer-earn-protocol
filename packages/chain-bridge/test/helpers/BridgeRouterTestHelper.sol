// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {BridgeRouter} from "../../src/router/BridgeRouter.sol";
import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {IBridgeAdapter} from "../../src/interfaces/IBridgeAdapter.sol";

/**
 * @title BridgeRouterTestHelper
 * @notice Helper contract for testing BridgeRouter
 * @dev Exposes internal functions and mappings for testing purposes
 */
contract BridgeRouterTestHelper is BridgeRouter {
    /**
     * @notice Constructor for BridgeRouterTestHelper
     * @param _accessManager Address of the access manager
     */
    constructor(
        address _accessManager
    ) BridgeRouter(_accessManager, new uint16[](0), new address[](0)) {}

    /**
     * @notice Updates the operationToAdapter mapping for testing
     * @param operationId ID of the operation
     * @param adapter Address of the adapter to associate with this operation
     */
    function setOperationToAdapter(
        bytes32 operationId,
        address adapter
    ) external {
        operationToAdapter[operationId] = adapter;
    }

    /**
     * @notice Removes an entry from the operationToAdapter mapping
     * @param operationId ID of the operation to remove
     */
    function removeOperationToAdapter(bytes32 operationId) external {
        delete operationToAdapter[operationId];
    }

    /**
     * @notice Gets the adapter associated with a operation
     * @param operationId ID of the operation
     * @return Address of the adapter associated with this operation
     */
    function getOperationAdapter(
        bytes32 operationId
    ) external view returns (address) {
        return operationToAdapter[operationId];
    }

    /**
     * @notice Sets the read request originator for testing purposes
     * @param requestId ID of the read request
     * @param originator Address of the originator to set
     */
    function setReadRequestOriginator(
        bytes32 requestId,
        address originator
    ) external {
        readRequestToOriginator[requestId] = originator;
    }

    /**
     * @notice Gets the originator associated with a read request
     * @param requestId ID of the read request
     * @return Address of the originator associated with this request
     */
    function getReadRequestOriginator(
        bytes32 requestId
    ) external view returns (address) {
        return readRequestToOriginator[requestId];
    }
}
