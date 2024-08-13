// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import {HarborCommand} from "../../src/contracts/HarborCommand.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {FleetCommanderAlreadyEnlisted, FleetCommanderNotEnlisted} from "../../src/errors/HarborCommandErrors.sol";
import {CallerIsNotGovernor} from "../../src/errors/AccessControlErrors.sol";

import {IHarborCommandEvents} from "../../src/events/IHarborCommandEvents.sol";

contract HarborCommandTest is Test {
    HarborCommand public harborCommand;
    ProtocolAccessManager public accessManager;
    address public governor = address(1);
    address public user = address(2);
    address public fleetCommander1 = address(3);
    address public fleetCommander2 = address(4);

    function setUp() public {
        // Deploy ProtocolAccessManager
        vm.prank(governor);
        accessManager = new ProtocolAccessManager(governor);

        // Deploy HarborCommand
        vm.prank(governor);
        harborCommand = new HarborCommand(address(accessManager));
    }

    function test_Constructor() public {}

    function test_EnlistFleetCommander() public {
        vm.prank(governor);

        vm.expectEmit(true, false, false, true);
        emit IHarborCommandEvents.FleetCommanderEnlisted(fleetCommander1);

        harborCommand.enlistFleetCommander(fleetCommander1);

        assertTrue(harborCommand.activeFleetCommanders(fleetCommander1));
        assertEq(harborCommand.fleetCommandersList(0), fleetCommander1);
    }

    function test_DecommissionFleetCommander() public {
        vm.startPrank(governor);
        harborCommand.enlistFleetCommander(fleetCommander1);

        vm.expectEmit(true, false, false, true);
        emit IHarborCommandEvents.FleetCommanderDecommissioned(fleetCommander1);

        harborCommand.decommissionFleetCommander(fleetCommander1);
        vm.stopPrank();

        assertFalse(harborCommand.activeFleetCommanders(fleetCommander1));
        assertEq(harborCommand.getActiveFleetCommanders().length, 0);
    }

    function test_GetActiveFleetCommanders() public {
        vm.startPrank(governor);
        harborCommand.enlistFleetCommander(fleetCommander1);
        harborCommand.enlistFleetCommander(fleetCommander2);
        vm.stopPrank();

        address[] memory activeCommanders = harborCommand
            .getActiveFleetCommanders();
        assertEq(activeCommanders.length, 2);
        assertEq(activeCommanders[0], fleetCommander1);
        assertEq(activeCommanders[1], fleetCommander2);
    }

    function test_OnlyGovernorCanEnlist() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, user)
        );
        harborCommand.enlistFleetCommander(fleetCommander1);
    }

    function test_CannotEnlistSameFleetCommanderTwice() public {
        vm.startPrank(governor);
        harborCommand.enlistFleetCommander(fleetCommander1);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderAlreadyEnlisted.selector,
                fleetCommander1
            )
        );
        harborCommand.enlistFleetCommander(fleetCommander1);
        vm.stopPrank();
    }

    function test_CannotDecommissionNonExistentFleetCommander() public {
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderNotEnlisted.selector,
                fleetCommander1
            )
        );
        harborCommand.decommissionFleetCommander(fleetCommander1);
    }
}
