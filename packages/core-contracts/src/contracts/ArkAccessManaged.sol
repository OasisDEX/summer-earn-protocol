// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import {IArk} from "../interfaces/IArk.sol";
import {IArkAccessManaged} from "../interfaces/IArkAccessManaged.sol";

import {IConfigurationManaged} from "../interfaces/IConfigurationManaged.sol";
import {IFleetCommander} from "../interfaces/IFleetCommander.sol";
import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";
import {LimitedAccessControl} from "./LimitedAccessControl.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

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
contract ArkAccessManaged is IArkAccessManaged, ProtocolAccessManaged {
    /**
     * @param accessManager The access manager address
     */
    constructor(address accessManager) ProtocolAccessManaged(accessManager) {}

    /**
     * @dev Modifier to check that the caller has the appropriate role to board
     *      Options being: Commander, another Ark or the RAFT contract
     */
    modifier onlyAuthorizedToBoard(address commander) {
        if (!hasCommanderRole()) {
            address msgSender = _msgSender();
            bool isRaft = msgSender ==
                IConfigurationManaged(address(this)).raft();

            if (!isRaft) {
                bool isArk = IFleetCommander(commander).isArkActive(msgSender);
                if (!isArk) {
                    revert CallerIsNotAuthorizedToBoard(msgSender);
                }
            }
        }
        _;
    }

    modifier onlyRaft() {
        if (_msgSender() != IConfigurationManaged(address(this)).raft()) {
            revert CallerIsNotRaft(_msgSender());
        }
        _;
    }

    modifier onlyCommander() {
        if (!hasCommanderRole()) {
            revert CallerIsNotCommander(_msgSender());
        }
        _;
    }

    function hasCommanderRole() internal view returns (bool) {
        return
            _accessManager.hasRole(
                generateRole(
                    ContractSpecificRoles.COMMANDER_ROLE,
                    address(this)
                ),
                _msgSender()
            );
    }
}
