// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {IConfigurationManager} from "../interfaces/IConfigurationManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "../errors/AccessControlErrors.sol";
import {IArkAccessManaged} from "../interfaces/IArkAccessManaged.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ArkAccessControl
 * @notice Extends the ProtocolAccessManaged contract with Ark specific AccessControl
 *         Used to specifically tie one FleetCommander to each Ark
 *
 * @dev One Ark specific role is defined:
 *   - Commander: is the fleet commander contract itself and couples an
 *        Ark to specific Fleet Commander
 *
 *   The Commander role is still declared on the access manager to centralise
 *   role definitions.
 */
contract ArkAccessManaged is
    IArkAccessManaged,
    Initializable,
    ProtocolAccessManaged,
    AccessControlUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __ArkAccessManaged_init(
        address accessManager
    ) public onlyInitializing {
        ProtocolAccessManaged.__ProtocolAccessManaged_init(accessManager);
        AccessControlUpgradeable.__AccessControl_init();
    }

    /**
     * @dev Modifier to check that the caller has the Commander role
     */
    modifier onlyCommander() {
        if (!hasRole(_accessManager.COMMANDER_ROLE(), msg.sender)) {
            revert CallerIsNotCommander(msg.sender);
        }
        _;
    }

    /* @inheritdoc IArkAccessControl */
    function grantCommanderRole(address account) external onlyGovernor {
        _grantRole(_accessManager.COMMANDER_ROLE(), account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeCommanderRole(address account) external onlyGovernor {
        _revokeRole(_accessManager.COMMANDER_ROLE(), account);
    }
}
