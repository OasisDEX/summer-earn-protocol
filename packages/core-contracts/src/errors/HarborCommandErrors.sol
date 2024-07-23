// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title HarborCommand Errors
 * @notice Custom errors for the HarborCommand contract
 */

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

/**
 * @notice Thrown when attempting to set the TipJar address to the zero address
 * @dev This error is thrown in both the enlistTipJar and refitTipJar functions
 */
error InvalidTipJarAddress();
