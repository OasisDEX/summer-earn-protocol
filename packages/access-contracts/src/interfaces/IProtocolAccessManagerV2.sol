// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IProtocolAccessManager} from "./IProtocolAccessManager.sol";

/**
 * @title IProtocolAccessManager
 * @notice Defines system roles and provides role based remote-access control for
 *         contracts that inherit from ProtocolAccessManaged contract
 */
interface IProtocolAccessManagerV2 {
    /**
     * @notice Grants the Operator role to a given account
     * @param fleetCommanderAddress The address of the fleet commander to grant the role for
     * @param account The account to which the Operator role will be granted
     *
     * @dev The operator role is used to restrict usage of a particular contract to a particular
     *      address. In the context of the fleet commander, only the Operator could deposit and
     *      withdraw for example
     */
    function grantOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;

    /**
     * @notice Revokes the Operator role from a given account
     * @param fleetCommanderAddress The address of the fleet commander to revoke the role for
     * @param account The account from which the Operator role will be revoked
     */
    function revokeOperatorRole(
        address fleetCommanderAddress,
        address account
    ) external;
}
