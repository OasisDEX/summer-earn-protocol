// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IHarborCommandEvents} from "../events/IHarborCommandEvents.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

/**
 * @title HarborCommand - Fleet Commander Management System
 * @dev This contract serves as a central registry for managing official Fleet Commanders in the system.
 *
 * The HarborCommand contract is responsible for:
 * 1. Maintaining a list of authorized Fleet Commanders.
 * 2. Providing functions to enlist new Fleet Commanders and decommission existing ones.
 * 3. Offering a way to verify the active status of Fleet Commanders.
 * 4. Ensuring that only authorized entities (Governors) can modify the Fleet Commander roster.
 *
 * Key features:
 * - Enlistment and decommissioning of Fleet Commanders with proper access control.
 * - Prevention of duplicate enlistments and erroneous decommissions.
 * - Efficient storage and retrieval of active Fleet Commanders.
 * - Event emission for transparent tracking of roster changes.
 *
 * This contract plays a crucial role in maintaining the integrity and security of the fleet management system
 * by providing a reliable source of truth for official fleet verification.
 * @custom:see IHarborCommand
 */
contract HarborCommand is
    ProtocolAccessManaged,
    IHarborCommandEvents,
    IHarborCommand
{
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping of addresses to their active status as Fleet Commanders
    mapping(address fleetCommander => bool isActive)
        public activeFleetCommanders;

    /// @notice List of all Fleet Commander addresses
    address[] public fleetCommandersList;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the HarborCommand contract
     * @param _accessManager Address of the access manager contract
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL GOVERNOR FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHarborCommand
    function enlistFleetCommander(
        address _fleetCommander
    ) external onlyGovernor {
        if (activeFleetCommanders[_fleetCommander]) {
            revert FleetCommanderAlreadyEnlisted(_fleetCommander);
        }
        activeFleetCommanders[_fleetCommander] = true;
        fleetCommandersList.push(_fleetCommander);
        emit FleetCommanderEnlisted(_fleetCommander);
    }

    /// @inheritdoc IHarborCommand
    function decommissionFleetCommander(
        address _fleetCommander
    ) external onlyGovernor {
        if (!activeFleetCommanders[_fleetCommander]) {
            revert FleetCommanderNotEnlisted(_fleetCommander);
        }
        activeFleetCommanders[_fleetCommander] = false;

        _removeFromList(_fleetCommander);

        emit FleetCommanderDecommissioned(_fleetCommander);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHarborCommand
    function getActiveFleetCommanders()
        external
        view
        override
        returns (address[] memory)
    {
        return fleetCommandersList;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Removes a Fleet Commander from the list
     * @dev This function uses the 'swap and pop' method for efficient removal
     * @param _fleetCommander Address of the Fleet Commander to remove
     */
    function _removeFromList(address _fleetCommander) internal {
        uint256 length = fleetCommandersList.length;
        for (uint256 i = 0; i < length; i++) {
            if (fleetCommandersList[i] == _fleetCommander) {
                // Swap with the last element and pop
                fleetCommandersList[i] = fleetCommandersList[length - 1];
                fleetCommandersList.pop();
                break;
            }
        }
    }
}
