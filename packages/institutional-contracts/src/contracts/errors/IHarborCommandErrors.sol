// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IHarborCommandErrors
 * @dev This file contains custom error definitions for the HarborCommand contract.
 * @notice These custom errors provide more gas-efficient and informative error handling
 * compared to traditional require statements with string messages.
 */
interface IHarborCommandErrors {
    /**
     * @notice Thrown when attempting to enlist a FleetCommander that is already enlisted
     * @param fleetCommander The address of the FleetCommander that was attempted to be enlisted
     */
    error FleetCommanderAlreadyEnlisted(address fleetCommander);

    /**
     * @notice Thrown when attempting to decommission a FleetCommander that is not currently enlisted
     * @param fleetCommander The address of the FleetCommander that was attempted to be decommissioned
     */
    error FleetCommanderNotEnlisted(address fleetCommander);
}
