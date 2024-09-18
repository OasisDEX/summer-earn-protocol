// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../../src/contracts/ConfigurationManager.sol";
import "../../src/contracts/ProtocolAccessManager.sol";
import "forge-std/Test.sol";
import {IConfigurationManagerEvents} from "../../src/events/IConfigurationManagerEvents.sol";

contract ConfigurationManagerTest is Test {
    ConfigurationManager public configurationManager;
    ProtocolAccessManager public accessManager;
    address public governor;
    address public nonGovernor;
    address public initialRaft;
    address public initialTipJar;
    address public initialTreasury;

    function setUp() public {
        governor = address(1);
        nonGovernor = address(2);
        initialRaft = address(3);
        initialTipJar = address(4);
        initialTreasury = address(5);

        // Setup AccessManager
        accessManager = new ProtocolAccessManager(governor);

        // Setup ConfigurationManager
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            raft: initialRaft,
            tipJar: initialTipJar,
            treasury: initialTreasury
        });
        configurationManager = new ConfigurationManager(address(accessManager));
        vm.prank(governor);
        configurationManager.initialize(params);
    }

    function test_Constructor() public {
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            raft: initialRaft,
            tipJar: initialTipJar,
            treasury: initialTreasury
        });
        configurationManager = new ConfigurationManager(address(accessManager));
        vm.prank(governor);
        configurationManager.initialize(params);
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
            treasury: initialTreasury
        });
        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature("ConfigurationManagerAlreadyInitialized()")
        );
        configurationManager.initialize(params);
    }

    function test_SetRaftByGovernor() public {
        address newRaft = address(5);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IConfigurationManagerEvents.RaftUpdated(newRaft);
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
        emit IConfigurationManagerEvents.TipJarUpdated(newTipJar);
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
            emit IConfigurationManagerEvents.RaftUpdated(newRafts[i]);
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
            emit IConfigurationManagerEvents.TipJarUpdated(newTipJars[i]);
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
        configurationManager.setRaft(address(0));
        assertEq(
            configurationManager.raft(),
            address(0),
            "Raft address should be set to zero address"
        );
    }

    function test_SetTipJarToZeroAddress() public {
        vm.prank(governor);
        configurationManager.setTipJar(address(0));
        assertEq(
            configurationManager.tipJar(),
            address(0),
            "TipJar address should be set to zero address"
        );
    }

    function test_SetTreasuryByGovernor() public {
        address newTreasury = address(13);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit IConfigurationManagerEvents.TreasuryUpdated(newTreasury);
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

    function test_SetTreasuryToZeroAddress() public {
        vm.prank(governor);
        configurationManager.setTreasury(address(0));
        assertEq(
            configurationManager.treasury(),
            address(0),
            "Treasury address should be set to zero address"
        );
    }
}
