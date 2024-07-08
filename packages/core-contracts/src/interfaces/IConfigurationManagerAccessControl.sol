// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title IConfigurationManagerAccessControl
 * @notice Defines the specific roles for ConfigurationManager contract,
 *         helper functions to manage them and enforce access control
 *
 * @dev 1 role is defined:
 *   - Governor: in charge of setting system wide parameters
 */
interface IConfigurationManagerAccessControl {
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
}
