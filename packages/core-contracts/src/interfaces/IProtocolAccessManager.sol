// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

/**
@dev Dynamic roles are roles that are not hardcoded in the contract but are defined by the protocol
* Members of this enum are treated as prefixes to the role genrated using prefix and target contract address    
* e.g generateRole(DynamicRoles.CURATOR_ROLE, address(this)) for FleetCommander, to generate the CURATOR_ROLE
* for the curator of the  FleetCommander contract
 */
enum DynamicRoles {
    CURATOR_ROLE
}

/**
 * @title IProtocolAccessManager
 * @notice Defines system roles and provides role based remote-access control for
 *         contracts that inherit from ProtocolAccessManaged contract
 */

interface IProtocolAccessManager {
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

    /**
     * @notice Grants the Super Keeper role to a given account
     *
     * @param account The account to which the Super Keeper role will be granted
     */
    function grantSuperKeeperRole(address account) external;

    /**
     * @notice Revokes the Super Keeper role from a given account
     *
     * @param account The account from which the Super Keeper role will be revoked
     */
    function revokeSuperKeeperRole(address account) external;

    /**
     * @notice Generates a role hash for a given role name and contract address
     * @param roleName The name of the role to generate
     * @param roleTargetContract The address of the contract to generate the role for
     * @return The generated role hash
     */
    function generateRole(
        DynamicRoles roleName,
        address roleTargetContract
    ) external pure returns (bytes32);

    /**
     * @notice Grants a dynamic role to a given account
     * @param roleName The name of the role to grant
     * @param roleTargetContract The address of the contract to grant the role for
     * @param account The account to which the role will be granted
     */
    function grantDynamicRole(
        DynamicRoles roleName,
        address roleTargetContract,
        address account
    ) external;

    /**
     * @notice Revokes a dynamic role from a given account
     * @param roleName The name of the role to revoke
     * @param roleTargetContract The address of the contract to revoke the role for
     * @param account The account from which the role will be revoked
     */
    function revokeDynamicRole(
        DynamicRoles roleName,
        address roleTargetContract,
        address account
    ) external;

    /**
     * @notice Revokes a dynamic role from the caller
     * @param roleName The name of the role to revoke
     * @param roleTargetContract The address of the contract to revoke the role for
     */
    function selfRevokeDynamicRole(
        DynamicRoles roleName,
        address roleTargetContract
    ) external;
}
