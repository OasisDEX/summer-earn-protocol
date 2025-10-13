// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IFleetCommander} from "./IFleetCommander.sol";

/**
 * @title ICrossChainFleetCommander
 * @notice Interface for CrossChain FleetCommander with cooldown protection
 */
interface ICrossChainFleetCommander {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when cooldown timestamp is propagated from sender to recipient
     * @param from The address that sent the shares
     * @param to The address that received the shares
     * @param cooldownTimestamp The cooldown timestamp that was propagated
     */
    event FleetCommanderCooldownPropagated(
        address indexed from,
        address indexed to,
        uint256 cooldownTimestamp
    );

    /**
     * @notice Emitted when the user cooldown period is updated
     * @param newCooldownPeriod The new cooldown period in seconds
     */
    event UserCooldownPeriodUpdated(uint256 newCooldownPeriod);

    /*//////////////////////////////////////////////////////////////
                            COOLDOWN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
}
