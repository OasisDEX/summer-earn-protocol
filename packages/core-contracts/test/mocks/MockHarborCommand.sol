// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract MockHarborCommand {
    mapping(address => bool) public activeFleetCommanders;

    function setActiveFleetCommander(
        address fleetCommander,
        bool isActive
    ) external {
        activeFleetCommanders[fleetCommander] = isActive;
    }
}
