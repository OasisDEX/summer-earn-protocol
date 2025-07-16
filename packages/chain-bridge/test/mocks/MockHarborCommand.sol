// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IHarborCommandMinimal} from "../../src/interfaces/IHarborCommandMinimal.sol";

/**
 * @title MockHarborCommand
 * @notice Mock implementation of HarborCommand for testing
 */
contract MockHarborCommand is IHarborCommandMinimal {
    mapping(address => bool) public activeFleetCommanders;

    constructor() {}

    /**
     * @notice Set whether a FleetCommander is active
     * @param _fleetCommander The address of the FleetCommander
     * @param _isActive Whether the FleetCommander is active
     */
    function setActiveFleetCommander(
        address _fleetCommander,
        bool _isActive
    ) external {
        activeFleetCommanders[_fleetCommander] = _isActive;
    }

    function testSkipper() public {}
}
