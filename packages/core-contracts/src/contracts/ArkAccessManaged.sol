// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "../errors/AccessControlErrors.sol";
import {IArkAccessManaged} from "../interfaces/IArkAccessManaged.sol";

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
    ProtocolAccessManaged,
    AccessControl
{
    /**
     * @param accessManager The access manager address
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}

    /**
     * @dev Modifier to check that the caller has the Commander role
     */
    modifier onlyCommander() {
        if (!hasRole(_accessManager.COMMANDER_ROLE(), msg.sender)) {
            revert CallerIsNotCommander(msg.sender);
        }
        _;
    }

    /**
     * @notice Hook executed before the Commander role is granted
     * @dev This function is called internally before granting the Commander role.
     *      It allows derived contracts to add custom logic or checks before the role is granted.
     *      Remember to always call the parent hook using `super._beforeGrantRoleHook(account)` in derived contracts.
     * @param account The address to which the Commander role will be granted
     */
    function _beforeGrantRoleHook(address account) internal virtual {}

    /**
     * @notice Hook executed before the Commander role is revoked
     * @dev This function is called internally before revoking the Commander role.
     *      It allows derived contracts to add custom logic or checks before the role is revoked.
     *      Remember to always call the parent hook using `super._beforeRevokeRoleHook(account)` in derived contracts.
     * @param account The address from which the Commander role will be revoked
     */
    function _beforeRevokeRoleHook(address account) internal virtual {}

    /* @inheritdoc IArkAccessControl */
    function grantCommanderRole(address account) external onlyGovernor {
        _beforeGrantRoleHook(account);
        _grantRole(_accessManager.COMMANDER_ROLE(), account);
    }

    /* @inheritdoc IArkAccessControl */
    function revokeCommanderRole(address account) external onlyGovernor {
        _beforeRevokeRoleHook(account);
        _revokeRole(_accessManager.COMMANDER_ROLE(), account);
    }
}
