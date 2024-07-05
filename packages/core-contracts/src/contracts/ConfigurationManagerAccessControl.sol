// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IConfigurationManagerAccessControl.sol";
import "../errors/AccessControlErrors.sol";

/**
 * @custom:see IConfigurationManagerAccessControl
 */
contract ConfigurationManagerAccessControl is
    IConfigurationManagerAccessControl,
    AccessControl
{
    /**
     * @dev The Governor role is in charge of setting the parameters of the system
     *      and also has the power to manage the different Fleet Commander roles
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /**
     * CONSTRUCTOR
     */

    /**
     * @param governor The account that will be granted the Governor role
     */
    constructor(address governor) {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
    }

    /**
     * @dev Modifier to check that the caller has the Admin role
     */
    modifier onlyAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert CallerIsNotAdmin(msg.sender);
        }
        _;
    }

    modifier onlyRoleAdmin() {
        if (
            !hasRole(DEFAULT_ADMIN_ROLE, msg.sender) ||
            !hasRole(GOVERNOR_ROLE, msg.sender)
        ) {
            revert CallerIsNotRoleAdmin(msg.sender);
        }
        _;
    }

    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /* @inheritdoc IConfigurationManagerAccessControl */
    function grantAdminRole(address account) external onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IConfigurationManagerAccessControl */
    function revokeAdminRole(address account) external onlyAdmin {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IConfigurationManagerAccessControl */
    function grantGovernorRole(address account) external onlyRoleAdmin {
        grantRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IConfigurationManagerAccessControl */
    function revokeGovernorRole(address account) external onlyRoleAdmin {
        revokeRole(GOVERNOR_ROLE, account);
    }
}
