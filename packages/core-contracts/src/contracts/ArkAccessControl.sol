// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IArkAccessControl.sol";
import "../errors/AccessControlErrors.sol";
import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

/**
 * @title ArkAccessControl
 * @notice Defines the specific roles for Ark contracts and the
 *         helper functions to manage them and to enforce the access control
 *
 * @dev In particular 3 main roles are defined:
 *   - Governor: in charge of setting the parameters of the system and also has the power
 *                 to manage the different Fleet Commander roles
 *   - Keeper: in charge of rebalancing the funds between the different Arks through the Fleet Commander
 *   - Commander: is the fleet commander contract itself and couples an Ark to specific Fleet Commander
 */
contract ArkAccessControl is IArkAccessControl, AccessControl {
    /**
     * @dev The Governor role is in charge of setting the parameters of the system
     *      and also has the power to manage the different Fleet Commander roles
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant COMMANDER_ROLE = keccak256("COMMANDER_ROLE");

    /**
     * CONSTRUCTOR
     */

    /**
     * @param configurationManager The configuration manager address
     */
    constructor(address configurationManager) {
        IConfigurationManager manager = IConfigurationManager(
            configurationManager
        );
        _grantRole(DEFAULT_ADMIN_ROLE, manager.governor());
        _grantRole(GOVERNOR_ROLE, manager.governor());
    }

    /**
     * @dev Modifier to check that the caller has the Admin role
     */
    modifier onlyGovernor() {
        if (!hasRole(GOVERNOR_ROLE, msg.sender)) {
            revert CallerIsNotGovernor(msg.sender);
        }
        _;
    }

    modifier onlyKeeper() {
        if (!hasRole(KEEPER_ROLE, msg.sender)) {
            revert CallerIsNotKeeper(msg.sender);
        }
        _;
    }

    modifier onlyCommander() {
        if (!hasRole(COMMANDER_ROLE, msg.sender)) {
            revert CallerIsNotCommander(msg.sender);
        }
        _;
    }

    /* @inheritdoc IArkAccessControl */
    function grantAdminRole(address account) external {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeAdminRole(address account) external {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function grantGovernorRole(address account) external {
        grantRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeGovernorRole(address account) external {
        revokeRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function grantKeeperRole(address account) external {
        grantRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeKeeperRole(address account) external {
        revokeRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function grantCommanderRole(address account) external {
        grantRole(COMMANDER_ROLE, account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeCommanderRole(address account) external {
        revokeRole(COMMANDER_ROLE, account);
    }
}
