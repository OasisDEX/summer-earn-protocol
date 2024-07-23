// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IHarborCommandEvents} from "../events/IHarborCommandEvents.sol";
import {FleetCommanderAlreadyEnlisted, FleetCommanderNotEnlisted, InvalidTipJarAddress} from "../errors/HarborCommandErrors.sol";
import {IHarborCommand} from "../interfaces/IHarborCommand.sol";

contract HarborCommand is
    ProtocolAccessManaged,
    IHarborCommandEvents,
    IHarborCommand
{
    mapping(address => bool) public activeFleetCommanders;
    address[] public fleetCommandersList;
    address public tipJar;

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
        for (uint i = 0; i < fleetCommandersList.length; i++) {
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

    /* @inheritdoc IHarborCommand */
    function enlistTipJar(address _newTipJar) external onlyGovernor {
        _setTipJar(_newTipJar);
        emit TipJarEnlisted(_newTipJar);
    }

    /* @inheritdoc IHarborCommand */
    function decommissionTipJar() external onlyGovernor {
        tipJar = address(0);
        emit TipJarDecommissioned();
    }

    /* @inheritdoc IHarborCommand */
    function refitTipJar(address _newTipJar) external onlyGovernor {
        _setTipJar(_newTipJar);
        emit TipJarRefitted(_newTipJar);
    }

    function getActiveFleetCommanders()
        external
        view
        returns (address[] memory)
    {
        return fleetCommandersList;
    }

    function _setTipJar(address _newTipJar) internal {
        if (_newTipJar == address(0)) {
            revert InvalidTipJarAddress();
        }
        tipJar = _newTipJar;
    }
}
