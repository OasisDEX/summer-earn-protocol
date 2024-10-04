// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";
import {LimitedAccessControl} from "./LimitedAccessControl.sol";

/**
 * @custom:see IProtocolAccessManager
 */
contract ProtocolAccessManager is IProtocolAccessManager, LimitedAccessControl {
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
     * @dev The Super Keeper role is in charge of rebalancing the funds between the different
     *         Arks through the Fleet Commander
     */
    bytes32 public constant SUPER_KEEPER_ROLE = keccak256("SUPER_KEEPER_ROLE");

    /**
     * @dev The Commander role is assigned to a FleetCommander and is used to restrict
     *          with whom associated arks can interact
     */
    bytes32 public constant COMMANDER_ROLE = keccak256("COMMANDER_ROLE");

    /**
     * @notice The Guardian role is in charge of managing the protocol's state in case of emergency
     */
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    constructor(address governor) {
        _grantRole(DEFAULT_ADMIN_ROLE, governor);
        _grantRole(GOVERNOR_ROLE, governor);
        _grantRole(GUARDIAN_ROLE, governor);
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

    // Override supportsInterface to include IProtocolAccessManager
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IProtocolAccessManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* @inheritdoc IProtocolAccessManager */
    function grantAdminRole(address account) external onlyAdmin {
        _grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function revokeAdminRole(address account) external onlyAdmin {
        _revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function grantGovernorRole(address account) external onlyAdmin {
        _grantRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function revokeGovernorRole(address account) external onlyAdmin {
        _revokeRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function grantKeeperRole(address account) external onlyGovernor {
        _grantRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function revokeKeeperRole(address account) external onlyGovernor {
        _revokeRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function grantSuperKeeperRole(address account) external onlyGovernor {
        _grantRole(SUPER_KEEPER_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function revokeSuperKeeperRole(address account) external onlyGovernor {
        _revokeRole(SUPER_KEEPER_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function grantGuardianRole(address account) external onlyGovernor {
        _grantRole(GUARDIAN_ROLE, account);
    }

    /* @inheritdoc IProtocolAccessManager */
    function revokeGuardianRole(address account) external onlyGovernor {
        _revokeRole(GUARDIAN_ROLE, account);
    }
}
