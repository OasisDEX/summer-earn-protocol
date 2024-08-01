// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../errors/AccessControlErrors.sol";

/**
 * @title LimitedAccessControl
 * @dev This contract extends OpenZeppelin's AccessControl, disabling direct role granting and revoking.
 * It's designed to be used as a base contract for more specific access control implementations.
 */
contract LimitedAccessControl is AccessControl {
    /**
     * @dev Overrides the grantRole function from AccessControl to disable direct role granting.
     * @param role The role that would be granted (unused in this implementation).
     * @param account The account that would receive the role (unused in this implementation).
     * @notice This function always reverts with a DirectGrantIsDisabled error.
     */
    function grantRole(bytes32 role, address account) public view override {
        revert DirectGrantIsDisabled(msg.sender);
    }

    /**
     * @dev Overrides the revokeRole function from AccessControl to disable direct role revoking.
     * @param role The role that would be revoked (unused in this implementation).
     * @param account The account that would lose the role (unused in this implementation).
     * @notice This function always reverts with a DirectRevokeIsDisabled error.
     */
    function revokeRole(bytes32 role, address account) public view override {
        revert DirectRevokeIsDisabled(msg.sender);
    }
}
