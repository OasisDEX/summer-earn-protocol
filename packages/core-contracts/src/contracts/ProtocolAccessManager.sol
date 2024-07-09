// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../errors/AccessControlErrors.sol";

/**
 * @custom:see IProtocolAccessManager
 */
contract ProtocolAccessManager is IProtocolAccessManager, AccessControl {
    /**
     * @dev The Governor role is in charge of setting the parameters of the system
     *      and also has the power to manage the different Fleet Commander roles.
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /**
     * @dev The Keeper role is in charge of rebalancing the funds between the different
     *         Arks through the Fleet Commander
     */
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /**
     * @dev The Commander role is assigned to a FleetCommander and is used to restrict
     *          with whom associated arks can interact
     */
    bytes32 public constant COMMANDER_ROLE = keccak256("COMMANDER_ROLE");

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

    /**
     * @dev Modifier to check that the caller has the Governor role
     */
    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    /**
     * @dev Modifier to check that the caller has the Keeper role
     */
    modifier onlyKeeper() {
        if (!hasRole(KEEPER_ROLE, msg.sender)) {
            revert CallerIsNotKeeper(msg.sender);
        }
        _;
    }

    /* @inheritdoc IProtocolAccessControl */
    function grantAdminRole(address account) external onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessControl */
    function revokeAdminRole(address account) external onlyAdmin {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessControl */
    function grantGovernorRole(address account) external onlyAdmin {
        grantRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessControl */
    function revokeGovernorRole(address account) external onlyAdmin {
        revokeRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessControl */
    function grantKeeperRole(address account) external onlyGovernor {
        grantRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessControl */
    function revokeKeeperRole(address account) external onlyGovernor {
        revokeRole(KEEPER_ROLE, account);
    }
}
