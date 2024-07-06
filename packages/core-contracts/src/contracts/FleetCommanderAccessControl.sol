// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFleetCommanderAccessControl} from "../interfaces/IFleetCommanderAccessControl.sol";
import "../errors/AccessControlErrors.sol";
import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";

/**
 * @title FleetCommanderAccessControl
 * @notice Defines the specific roles for the FleetCommander contract and the
 *         helper functions to manage them and to enforce the access control
 *
 * @dev In particular 2 main roles are defined:
 *   - Governor: in charge of setting the parameters of the system and also has the power to
 *                 manage the different Fleet Commander roles
 *   - Keeper: in charge of rebalancing the funds between the different Arks through the Fleet Commander
 */
contract FleetCommanderAccessControl is
    IFleetCommanderAccessControl,
    AccessControl
{
    /**
     * @dev The Governor role is in charge of setting the parameters of the system
     *      and also has the power to manage the different Fleet Commander roles
     */
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    /**
     * @dev The Keeper role is in charge of rebalancing the funds between the different
     *         Arks through the Fleet Commander
     */
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    /**
     * CONSTRUCTOR
     */

    /**
     * @param configurationManager The address of the ConfigurationManager.sol contract
     */
    constructor(address configurationManager) {
        IConfigurationManager manager = IConfigurationManager(
            configurationManager
        );
        _grantRole(DEFAULT_ADMIN_ROLE, manager.governor());
        _grantRole(GOVERNOR_ROLE, manager.governor());
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

    /**
     * EXTERNAL/PUBLIC FUNCTIONS
     */

    /* @inheritdoc IFleetCommanderAccessControl */
    function grantAdminRole(address account) external {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IFleetCommanderAccessControl */
    function revokeAdminRole(address account) external {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    /* @inheritdoc IFleetCommanderAccessControl */
    function grantGovernorRole(address account) external {
        grantRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IFleetCommanderAccessControl */
    function revokeGovernorRole(address account) external {
        revokeRole(GOVERNOR_ROLE, account);
    }

    /* @inheritdoc IFleetCommanderAccessControl */
    function grantKeeperRole(address account) external {
        grantRole(KEEPER_ROLE, account);
    }

    /* @inheritdoc IFleetCommanderAccessControl */
    function revokeKeeperRole(address account) external {
        revokeRole(KEEPER_ROLE, account);
    }
}
