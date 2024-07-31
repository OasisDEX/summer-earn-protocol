// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {ITipJar} from "../../src/interfaces/ITipJar.sol";
import {ITipJarEvents} from "../../src/interfaces/ITipJarEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {TipJar} from "../../src/contracts/TipJar.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import "../../src/libraries/PercentageUtils.sol";
import "../../src/types/Percentage.sol";
import {ConfigurationManagerMock} from "../mocks/ConfigurationManagerMock.sol";


contract TipJarTest is Test, ITipJarEvents {
    using PercentageUtils for uint256;

    address public governor = address(1);
    address public keeper = address(2);
    address public treasury = address(3);
    FleetCommanderMock public fleetCommander;
    ConfigurationManagerMock public configManager;
    ERC20Mock public underlyingToken;
    TipJar public tipJar;
    ProtocolAccessManager public accessManager;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantKeeperRole(keeper);

        underlyingToken = new ERC20Mock();
        configManager = new ConfigurationManagerImplMock(address(tipJar));

        Percentage initialTipRate = PercentageUtils.fromFraction(100, 10000); // 1%
        fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            initialTipRate
        );

        tipJar = new TipJar(address(accessManager), treasury);
        configManager.setTipRate(100); // 1%

        vm.prank(address(fleetCommander));
        underlyingToken.approve(address(fleetCommander), type(uint256).max);
    }

    function testAddTipStream() public {
        vm.prank(governor);
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);

        ITipJar.TipStream memory stream = tipJar.getTipStream(address(4));
        assertEq(stream.recipient, address(4));
        assertEq(stream.allocation.rawValue, 2000);
        assertEq(stream.minimumTerm, block.timestamp + 1 days);
    }

    function testUpdateTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);

        vm.warp(block.timestamp + 2 days);
        tipJar.updateTipStream(address(4), 3000, block.timestamp + 3 days);
        vm.stopPrank();

        ITipJar.TipStream memory stream = tipJar.getTipStream(address(4));
        assertEq(stream.recipient, address(4));
        assertEq(stream.allocation.rawValue, 3000);
        assertEq(stream.minimumTerm, block.timestamp + 3 days);
    }

    function testRemoveTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);

        vm.warp(block.timestamp + 2 days);
        tipJar.removeTipStream(address(4));
        vm.stopPrank();

        ITipJar.TipStream memory stream = tipJar.getTipStream(address(4));
        assertEq(stream.recipient, address(0));
        assertEq(stream.allocation.rawValue, 0);
        assertEq(stream.minimumTerm, 0);
    }

    function testGetAllTipStreams() public {
        vm.startPrank(governor);
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);
        tipJar.addTipStream(address(5), 3000, block.timestamp + 2 days);
        vm.stopPrank();

        ITipJar.TipStream[] memory streams = tipJar.getAllTipStreams();
        assertEq(streams.length, 2);
        assertEq(streams[0].recipient, address(4));
        assertEq(streams[1].recipient, address(5));
    }

    function testShake() public {
        // Setup tip streams
        vm.prank(governor);
        tipJar.addTipStream(address(4), 6000, block.timestamp);
        tipJar.addTipStream(address(5), 3000, block.timestamp);

        // Setup mock fleet commander with some balance
        uint256 initialBalance = 1000 ether;
        underlyingToken.mint(address(fleetCommander), initialBalance);
        vm.prank(address(fleetCommander));
        fleetCommander.deposit(initialBalance, address(tipJar));

        // Shake the jar
        tipJar.shake(fleetCommander);

        // Check balances
        assertEq(underlyingToken.balanceOf(address(4)), 600 ether);
        assertEq(underlyingToken.balanceOf(address(5)), 300 ether);
        assertEq(underlyingToken.balanceOf(treasury), 100 ether);
    }

    function testFailAddTipStreamNonGovernor() public {
        vm.prank(address(6));
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);
    }

    function testFailUpdateTipStreamBeforeMinTerm() public {
        vm.prank(governor);
        tipJar.addTipStream(address(4), 2000, block.timestamp + 1 days);

        vm.prank(governor);
        tipJar.updateTipStream(address(4), 3000, block.timestamp + 2 days);
    }

    function testFailExceedTotalAllocation() public {
        vm.startPrank(governor);
        tipJar.addTipStream(address(4), 6000, block.timestamp);
        tipJar.addTipStream(address(5), 5000, block.timestamp);
    }

    function testSetTreasuryAddress() public {
        address newTreasury = address(6);
        vm.prank(governor);
        tipJar.setTreasuryAddress(newTreasury);
        assertEq(tipJar.treasuryAddress(), newTreasury);
    }
}

contract ConfigurationManagerImplMock is ConfigurationManagerMock {
    constructor(address _tipJar) ConfigurationManagerMock(_tipJar) {}

    function setTipJar(address newTipJar) external override {
//        tipJar = newTipJar;
    }
}