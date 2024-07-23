// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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

    /**
     * @notice Emitted when a new TipJar is enlisted
     * @param newTipJar The address of the new TipJar
     */
    event TipJarEnlisted(address indexed newTipJar);

    /**
     * @notice Emitted when the TipJar is decommissioned
     */
    event TipJarDecommissioned();

    /**
     * @notice Emitted when the TipJar is refitted (updated)
     * @param newTipJar The address of the new TipJar
     */
    event TipJarRefitted(address indexed newTipJar);
}
