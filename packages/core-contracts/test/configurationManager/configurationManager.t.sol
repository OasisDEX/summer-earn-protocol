// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../src/contracts/ConfigurationManager.sol";
import "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {IConfigurationManagerEvents} from "../../src/events/IConfigurationManagerEvents.sol";
import "forge-std/Test.sol";

contract ConfigurationManagerTest is Test {
    ConfigurationManager public configurationManager;
    ProtocolAccessManager public accessManager;
    address public governor;
    address public guardian;
    address public nonGovernor;
    address public initialRaft;
    address public initialTipJar;
    address public initialTreasury;
    address public initialHarborCommand;
    address public initialFleetCommanderRewardsManagerFactory;

    function setUp() public {
        governor = address(1);
        guardian = address(1);
        nonGovernor = address(2);
        initialRaft = address(3);
        initialTipJar = address(4);
        initialTreasury = address(5);
        initialHarborCommand = address(6);
        initialFleetCommanderRewardsManagerFactory = address(7);

        // Setup AccessManager
        accessManager = new ProtocolAccessManager(governor);

        // Setup ConfigurationManager
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            raft: initialRaft,
            tipJar: initialTipJar,
            treasury: initialTreasury,
            harborCommand: initialHarborCommand,
            fleetCommanderRewardsManagerFactory: initialFleetCommanderRewardsManagerFactory
        });
        configurationManager = new ConfigurationManager(address(accessManager));
        vm.prank(governor);
        configurationManager.initializeConfiguration(params);
    }

    function test_Constructor() public {
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            raft: initialRaft,
            tipJar: initialTipJar,
            treasury: initialTreasury,
            harborCommand: initialHarborCommand,
            fleetCommanderRewardsManagerFactory: initialFleetCommanderRewardsManagerFactory
        });
        configurationManager = new ConfigurationManager(address(accessManager));
        vm.prank(governor);
        configurationManager.initializeConfiguration(params);
        assertEq(
            configurationManager.raft(),
            initialRaft,
            "Initial Raft address should be set correctly"
        );
        assertEq(
            configurationManager.tipJar(),
            initialTipJar,
            "Initial TipJar address should be set correctly"
        );
        assertEq(
            configurationManager.treasury(),
            initialTreasury,
            "Initial Treasury address should be set correctly"
        );
    }

    function test_Initialize_ShouldFail() public {
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            raft: initialRaft,
            tipJar: initialTipJar,
            treasury: initialTreasury,
            harborCommand: address(0),
            fleetCommanderRewardsManagerFactory: address(0)
        });
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature("ConfigurationManagerAlreadyInitialized()")
        );
        configurationManager.initializeConfiguration(params);
    }

    function test_SetRaftByGovernor() public {
        address newRaft = address(5);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IConfigurationManagerEvents.RaftUpdated(initialRaft, newRaft);
        configurationManager.setRaft(newRaft);
        assertEq(
            configurationManager.raft(),
            newRaft,
            "Raft address should be updated"
        );
    }

    function test_SetRaftByNonGovernor() public {
        address newRaft = address(5);
        vm.prank(nonGovernor);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", nonGovernor)
        );
        configurationManager.setRaft(newRaft);
    }

    function test_SetTipJarByGovernor() public {
        address newTipJar = address(6);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IConfigurationManagerEvents.TipJarUpdated(
            initialTipJar,
            newTipJar
        );
        configurationManager.setTipJar(newTipJar);
        assertEq(
            configurationManager.tipJar(),
            newTipJar,
            "TipJar address should be updated"
        );
    }

    function test_SetTipJarByNonGovernor() public {
        address newTipJar = address(6);
        vm.prank(nonGovernor);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", nonGovernor)
        );
        configurationManager.setTipJar(newTipJar);
    }

    function test_MultipleRaftUpdates() public {
        address[] memory newRafts = new address[](3);
        newRafts[0] = address(7);
        newRafts[1] = address(8);
        newRafts[2] = address(9);

        for (uint256 i = 0; i < newRafts.length; i++) {
            vm.prank(governor);
            vm.expectEmit(true, true, true, true);
            if (i == 0) {
                emit IConfigurationManagerEvents.RaftUpdated(
                    initialRaft,
                    newRafts[i]
                );
            } else {
                emit IConfigurationManagerEvents.RaftUpdated(
                    newRafts[i - 1],
                    newRafts[i]
                );
            }
            configurationManager.setRaft(newRafts[i]);
            assertEq(
                configurationManager.raft(),
                newRafts[i],
                "Raft address should be updated"
            );
        }
    }

    function test_MultipleTipJarUpdates() public {
        address[] memory newTipJars = new address[](3);
        newTipJars[0] = address(10);
        newTipJars[1] = address(11);
        newTipJars[2] = address(12);

        for (uint256 i = 0; i < newTipJars.length; i++) {
            vm.prank(governor);
            vm.expectEmit(true, true, true, true);
            if (i == 0) {
                emit IConfigurationManagerEvents.TipJarUpdated(
                    initialTipJar,
                    newTipJars[i]
                );
            } else {
                emit IConfigurationManagerEvents.TipJarUpdated(
                    newTipJars[i - 1],
                    newTipJars[i]
                );
            }
            configurationManager.setTipJar(newTipJars[i]);
            assertEq(
                configurationManager.tipJar(),
                newTipJars[i],
                "TipJar address should be updated"
            );
        }
    }

    function test_SetRaftToZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        configurationManager.setRaft(address(0));
    }

    function test_SetTipJarToZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        configurationManager.setTipJar(address(0));
    }

    function test_SetTreasuryToZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        configurationManager.setTreasury(address(0));
    }

    function test_SetHarborCommandToZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("AddressZero()"));
        configurationManager.setHarborCommand(address(0));
    }

    function test_SetTreasuryByGovernor() public {
        address newTreasury = address(13);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IConfigurationManagerEvents.TreasuryUpdated(
            initialTreasury,
            newTreasury
        );
        configurationManager.setTreasury(newTreasury);
        assertEq(
            configurationManager.treasury(),
            newTreasury,
            "Treasury address should be updated"
        );
    }

    function test_SetTreasuryByNonGovernor() public {
        address newTreasury = address(13);
        vm.prank(nonGovernor);
        vm.expectRevert(
            abi.encodeWithSignature("CallerIsNotGovernor(address)", nonGovernor)
        );
        configurationManager.setTreasury(newTreasury);
    }
}
