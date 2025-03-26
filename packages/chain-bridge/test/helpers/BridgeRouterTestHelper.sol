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
     * @param _owner Address of the owner
     */
    constructor(address _owner) BridgeRouter(_owner) {}

    /**
     * @notice Updates the transferToAdapter mapping for testing
     * @param transferId ID of the transfer
     * @param adapter Address of the adapter to associate with this transfer
     */
    function setTransferToAdapter(
        bytes32 transferId,
        address adapter
    ) external {
        transferToAdapter[transferId] = adapter;
    }

    /**
     * @notice Removes an entry from the transferToAdapter mapping
     * @param transferId ID of the transfer to remove
     */
    function removeTransferToAdapter(bytes32 transferId) external {
        delete transferToAdapter[transferId];
    }

    /**
     * @notice Gets the adapter associated with a transfer
     * @param transferId ID of the transfer
     * @return Address of the adapter associated with this transfer
     */
    function getTransferAdapter(
        bytes32 transferId
    ) external view returns (address) {
        return transferToAdapter[transferId];
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
