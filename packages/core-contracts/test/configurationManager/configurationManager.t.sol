// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "forge-std/Test.sol";
import "../../src/contracts/ConfigurationManager.sol";
import "../../src/contracts/ProtocolAccessManager.sol";
import "../../src/types/ConfigurationManagerTypes.sol";

contract ConfigurationManagerTest is Test {
    ConfigurationManager public configManager;
    ProtocolAccessManager public accessManager;
    address public governor;
    address public nonGovernor;
    address public initialRaft;
    address public initialTipJar;

    event RaftUpdated(address newRaft);
    event TipJarUpdated(address newTipJar);

    function setUp() public {
        governor = address(1);
        nonGovernor = address(2);
        initialRaft = address(3);
        initialTipJar = address(4);

        // Setup AccessManager
        accessManager = new ProtocolAccessManager(governor);

        // Setup ConfigurationManager
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            accessManager: address(accessManager),
            raft: initialRaft,
            tipJar: initialTipJar
        });
        configManager = new ConfigurationManager(params);
    }

    function test_Constructor() public {
        ConfigurationManagerParams memory params = ConfigurationManagerParams({
            accessManager: address(accessManager),
            raft: initialRaft,
            tipJar: initialTipJar
        });
        configManager = new ConfigurationManager(params);
        assertEq(
            configManager.raft(),
            initialRaft,
            "Initial Raft address should be set correctly"
        );
        assertEq(
            configManager.tipJar(),
            initialTipJar,
            "Initial TipJar address should be set correctly"
        );
    }

    function test_SetRaftByGovernor() public {
        address newRaft = address(5);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit RaftUpdated(newRaft);
        configManager.setRaft(newRaft);
        assertEq(
            configManager.raft(),
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
        configManager.setRaft(newRaft);
    }

    function test_SetTipJarByGovernor() public {
        address newTipJar = address(6);
        vm.prank(governor);
        vm.expectEmit(true, true, true, true);
        emit TipJarUpdated(newTipJar);
        configManager.setTipJar(newTipJar);
        assertEq(
            configManager.tipJar(),
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
        configManager.setTipJar(newTipJar);
    }

    function test_MultipleRaftUpdates() public {
        address[] memory newRafts = new address[](3);
        newRafts[0] = address(7);
        newRafts[1] = address(8);
        newRafts[2] = address(9);

        for (uint i = 0; i < newRafts.length; i++) {
            vm.prank(governor);
            vm.expectEmit(true, true, true, true);
            emit RaftUpdated(newRafts[i]);
            configManager.setRaft(newRafts[i]);
            assertEq(
                configManager.raft(),
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

        for (uint i = 0; i < newTipJars.length; i++) {
            vm.prank(governor);
            vm.expectEmit(true, true, true, true);
            emit TipJarUpdated(newTipJars[i]);
            configManager.setTipJar(newTipJars[i]);
            assertEq(
                configManager.tipJar(),
                newTipJars[i],
                "TipJar address should be updated"
            );
        }
    }

    function test_SetRaftToZeroAddress() public {
        vm.prank(governor);
        configManager.setRaft(address(0));
        assertEq(
            configManager.raft(),
            address(0),
            "Raft address should be set to zero address"
        );
    }

    function test_SetTipJarToZeroAddress() public {
        vm.prank(governor);
        configManager.setTipJar(address(0));
        assertEq(
            configManager.tipJar(),
            address(0),
            "TipJar address should be set to zero address"
        );
    }
}
