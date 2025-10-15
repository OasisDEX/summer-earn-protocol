// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface IHarborCommandEvents {
    /**
     * @notice Emitted when a new FleetCommander is enlisted
     * @param fleetCommander The address of the enlisted FleetCommander
     */
    event FleetCommanderEnlisted(address indexed fleetCommander);

    /**
     * @notice Emitted when a FleetCommander is decommissioned
     * @param fleetCommander The address of the decommissioned FleetCommander
     */
    event FleetCommanderDecommissioned(address indexed fleetCommander);
}
