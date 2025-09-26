// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BridgeTypes} from "../../src/libraries/BridgeTypes.sol";
import {BridgeRouter} from "../../src/router/BridgeRouter.sol";

/**
 * @title BridgeRouterTestHelper
 * @notice Helper contract for testing BridgeRouter
 * @dev Exposes internal functions and mappings for testing purposes
 */
contract BridgeRouterTestHelper is BridgeRouter {
    /// @notice Flag to simulate revert behavior for testing
    bool public shouldRevert = false;

    /**
     * @notice Constructor for BridgeRouterTestHelper
     * @param _accessManager Address of the access manager
     * @param _registry Address of the registry
     */

    constructor(
        address _accessManager,
        address _registry
    ) BridgeRouter(_accessManager, _registry) {
        // Initialize any test-specific state here
    }

    /**
     * @notice Updates the operationToAdapter mapping for testing
     * @param operationId ID of the operation
     * @param adapter Address of the adapter to associate with this operation
     */
    // READ_STATE helper removed: operationToAdapter no longer exists

    /**
     * @notice Removes an entry from the operationToAdapter mapping
     * @param operationId ID of the operation to remove
     */
    // READ_STATE helper removed

    /**
     * @notice Gets the adapter associated with a operation
     * @param operationId ID of the operation
     * @return Address of the adapter associated with this operation
     */
    // READ_STATE helper removed

    /**
     * @notice Sets the read request originator for testing purposes
     * @param requestId ID of the read request
     * @param originator Address of the originator to set
     */
    // READ_STATE helper removed

    /**
     * @notice Gets the originator associated with a read request
     * @param requestId ID of the read request
     * @return Address of the originator associated with this request
     */
    // READ_STATE helper removed

    /**
     * @notice Sets whether operations should revert for testing purposes
     * @param _shouldRevert Whether operations should revert
     */
    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function testSkipper() public {}

    /**
     * @notice Exposes a failed delivery record for testing assertions
     */
    function getFailedDeliveryRecord(
        bytes32 operationId
    )
        external
        view
        returns (
            BridgeTypes.OperationType operationType,
            address adapter,
            uint16 sourceChainId,
            bytes memory operationPayload,
            uint256 failedAt
        )
    {
        FailedDeliveryRecord memory r = failedDeliveries[operationId];
        return (
            r.operationType,
            r.adapter,
            r.sourceChainId,
            r.operationPayload,
            r.failedAt
        );
    }
}
