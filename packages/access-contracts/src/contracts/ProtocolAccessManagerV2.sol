// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ContractSpecificRoles} from "../interfaces/IProtocolAccessManager.sol";
import {IProtocolAccessManagerV2} from "../interfaces/IProtocolAccessManagerV2.sol";
import {ProtocolAccessManager} from "./ProtocolAccessManager.sol";
import {IProtocolAccessManager} from "../interfaces/IProtocolAccessManager.sol";

/**
 * @title ProtocolAccessManagerV2
 * @notice This contract extends ProtocolAccessManager with a new Operator role
 */
contract ProtocolAccessManagerV2 is
    IProtocolAccessManagerV2,
    ProtocolAccessManager
{
    /**
     * @notice Initializes the ProtocolAccessManagerV2 contract
     * @param governor Address of the initial governor
     */
    constructor(address governor) ProtocolAccessManager(governor) {
        // Empty on purpose
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function grantOperatorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        grantContractSpecificRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }

    /// @inheritdoc IProtocolAccessManagerV2
    function revokeOperatorRole(
        address fleetCommanderAddress,
        address account
    ) public onlyGovernor {
        revokeContractSpecificRole(
            ContractSpecificRoles.OPERATOR_ROLE,
            fleetCommanderAddress,
            account
        );
    }
}
