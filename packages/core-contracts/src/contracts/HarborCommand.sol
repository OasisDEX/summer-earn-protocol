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
 */
contract HarborCommand is
    ProtocolAccessManaged,
    IHarborCommandEvents,
    IHarborCommand
{
    mapping(address => bool) public activeFleetCommanders;
    address[] public fleetCommandersList;

    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /* @inheritdoc IHarborCommand */
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

    /* @inheritdoc IHarborCommand */
    function decommissionFleetCommander(
        address _fleetCommander
    ) external onlyGovernor {
        if (!activeFleetCommanders[_fleetCommander]) {
            revert FleetCommanderNotEnlisted(_fleetCommander);
        }
        activeFleetCommanders[_fleetCommander] = false;

        // Remove from list
        for (uint256 i = 0; i < fleetCommandersList.length; i++) {
            if (fleetCommandersList[i] == _fleetCommander) {
                fleetCommandersList[i] = fleetCommandersList[
                    fleetCommandersList.length - 1
                ];
                fleetCommandersList.pop();
                break;
            }
        }

        emit FleetCommanderDecommissioned(_fleetCommander);
    }

    function getActiveFleetCommanders()
        external
        view
        returns (address[] memory)
    {
        return fleetCommandersList;
    }
}
