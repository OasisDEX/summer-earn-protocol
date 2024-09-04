// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {FleetCommanderAlreadyEnlisted, FleetCommanderNotEnlisted} from "../errors/HarborCommandErrors.sol";
import {IHarborCommandEvents} from "../events/IHarborCommandEvents.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";

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
