// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
 * @title IArkAccessControl
 * @notice Defines the specific roles for Ark contracts and
 *         helper functions that manage them and enforce access control
 */
interface IArkAccessManaged {
    /**
     * @notice Grants the Commander role to a given account
     *
     * @param account The account to which the Commander role will be granted
     */
    function grantCommanderRole(address account) external;

    /**
     * @notice Revokes the Commander role from a given account
     *
     * @param account The account from which the Commander role will be revoked
     */
    function revokeCommanderRole(address account) external;
}
