// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IFleetCommanderAccessControl
 * @notice Defines the specific roles for the FleetCommander contract and the
 *         helper functions to manage them and to enforce the access control
 */
interface IFleetCommanderAccessControl {
    /**
     * ERRORS
     */
    error CallerIsNotGovernor(address caller);
    error CallerIsNotKeeper(address caller);
    error CallerIsNotAdmin(address caller);
    error CallerIsNotRoleAdmin(address caller);

    /**
     * FUNCTIONS
     */

    /**
     * @notice Grants the Admin role to a given account
     *
     * @param account The account to which the Admin role will be granted
     */
    function grantAdminRole(address account) external;

    /**
     * @notice Revokes the Admin role from a given account
     *
     * @param account The account from which the Admin role will be revoked
     */
    function revokeAdminRole(address account) external;

    /**
     * @notice Grants the Governor role to a given account
     *
     * @param account The account to which the Governor role will be granted
     */
    function grantGovernorRole(address account) external;

    /**
     * @notice Revokes the Governor role from a given account
     *
     * @param account The account from which the Governor role will be revoked
     */
    function revokeGovernorRole(address account) external;

    /**
     * @notice Grants the Keeper role to a given account
     *
     * @param account The account to which the Keeper role will be granted
     */
    function grantKeeperRole(address account) external;

    /**
     * @notice Revokes the Keeper role from a given account
     *
     * @param account The account from which the Keeper role will be revoked
     */
    function revokeKeeperRole(address account) external;
}
