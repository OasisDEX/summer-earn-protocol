// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

/**
 * @title IHarborCommandMinimal
 * @notice Minimal interface for HarborCommand containing only the functions needed by the bridge adapter
 * @dev This is a subset of the full IHarborCommand interface to avoid circular dependencies
 */
interface IHarborCommandMinimal {
    /**
     * @notice Checks if a FleetCommander is currently active
     * @param _fleetCommander The address of the FleetCommander to check
     * @return bool True if the FleetCommander is active, false otherwise
     */
    function activeFleetCommanders(
        address _fleetCommander
    ) external view returns (bool);
}
