// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHarborCommandErrors} from "../errors/IHarborCommandErrors.sol";

/**
 * @title IHarborCommand
 * @notice Interface for the HarborCommand contract which manages FleetCommanders and TipJar
 * @dev This interface defines the external functions and events for HarborCommand
 */
interface IHarborCommand is IHarborCommandErrors {
    /**
     * @notice Enlists a new FleetCommander
     * @dev Only callable by the governor
     * @param _fleetCommander The address of the FleetCommander to enlist
     * @custom:error FleetCommanderAlreadyEnlisted Thrown if the FleetCommander is already enlisted
     */
    function enlistFleetCommander(address _fleetCommander) external;

    /**
     * @notice Decommissions an enlisted FleetCommander
     * @dev Only callable by the governor
     * @param _fleetCommander The address of the FleetCommander to decommission
     * @custom:error FleetCommanderNotEnlisted Thrown if the FleetCommander is not enlisted
     */
    function decommissionFleetCommander(address _fleetCommander) external;

    /**
     * @notice Retrieves the list of active FleetCommanders
     * @return An array of addresses representing the active FleetCommanders
     */
    function getActiveFleetCommanders()
        external
        view
        returns (address[] memory);

    /**
     * @notice Checks if a FleetCommander is currently active
     * @param _fleetCommander The address of the FleetCommander to check
     * @return bool True if the FleetCommander is active, false otherwise
     */
    function activeFleetCommanders(
        address _fleetCommander
    ) external view returns (bool);

    /**
     * @notice Retrieves the FleetCommander at a specific index in the list
     * @param index The index in the list of FleetCommanders
     * @return The address of the FleetCommander at the specified index
     */
    function fleetCommandersList(uint256 index) external view returns (address);
}
