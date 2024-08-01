// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {ITipJar} from "../../src/interfaces/ITipJar.sol";
import {ITipJarEvents} from "../../src/interfaces/ITipJarEvents.sol";
import {IConfigurationManager} from "../../src/interfaces/IConfigurationManager.sol";
import {IFleetCommander} from "../../src/interfaces/IFleetCommander.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {TipJar} from "../../src/contracts/TipJar.sol";
import {ProtocolAccessManager} from "../../src/contracts/ProtocolAccessManager.sol";
import {PercentageUtils} from "../../src/libraries/PercentageUtils.sol";
import {Percentage, fromPercentage} from "../../src/types/Percentage.sol";
import {ConfigurationManagerMock} from "../mocks/ConfigurationManagerMock.sol";
import "../../src/errors/TipJarErrors.sol";
import "../../src/errors/AccessControlErrors.sol";

contract TipJarTest is Test, ITipJarEvents {
    using PercentageUtils for uint256;

    address public governor = address(1);
    address public keeper = address(2);
    address public treasury = address(3);
    address public mockTipStreamRecipient = address(4);

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

        Percentage initialTipRate = PercentageUtils.fromDecimalPercentage(1); // 1%
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

    function test_Constructor() public {
        assertEq(tipJar.treasuryAddress(), treasury);

        // Test with a different treasury address
        address newTreasury = address(42);
        TipJar newTipJar = new TipJar(address(accessManager), newTreasury);
        assertEq(newTipJar.treasuryAddress(), newTreasury);
    }

    function test_AddTipStream() public {
        vm.prank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp + 1 days
        );

        ITipJar.TipStream memory stream = tipJar.getTipStream(
            mockTipStreamRecipient
        );
        assertEq(stream.recipient, mockTipStreamRecipient);
        assertTrue(
            stream.allocation == PercentageUtils.fromDecimalPercentage(20)
        );
        assertEq(stream.minimumTerm, block.timestamp + 1 days);
    }

    function test_UpdateTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp + 1 days
        );

        vm.warp(block.timestamp + 2 days);
        tipJar.updateTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp + 3 days
        );
        vm.stopPrank();

        ITipJar.TipStream memory stream = tipJar.getTipStream(address(4));
        assertEq(stream.recipient, mockTipStreamRecipient);
        assertEq(fromPercentage(stream.allocation), 30);
        assertEq(stream.minimumTerm, block.timestamp + 3 days);
    }

    function test_RemoveTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp + 1 days
        );

        vm.warp(block.timestamp + 2 days);
        tipJar.removeTipStream(address(4));
        vm.stopPrank();

        ITipJar.TipStream memory stream = tipJar.getTipStream(
            mockTipStreamRecipient
        );
        assertEq(stream.recipient, address(0));
        assertEq(fromPercentage(stream.allocation), 0);
        assertEq(stream.minimumTerm, 0);
    }

    function test_GetAllTipStreams() public {
        address anotherMockTipStreamParticipant = address(5);
        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp + 1 days
        );
        tipJar.addTipStream(
            anotherMockTipStreamParticipant,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp + 2 days
        );
        vm.stopPrank();

        ITipJar.TipStream[] memory streams = tipJar.getAllTipStreams();
        assertEq(streams.length, 2);
        assertEq(streams[0].recipient, mockTipStreamRecipient);
        assertEq(streams[1].recipient, anotherMockTipStreamParticipant);
    }

    function test_Shake() public {
        address anotherMockTipStreamParticipant = address(5);

        // Setup tip streams
        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(60),
            block.timestamp
        );
        tipJar.addTipStream(
            anotherMockTipStreamParticipant,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp
        );
        vm.stopPrank();

        // Setup mock fleet commander with some balance
        uint256 initialBalance = 1000 ether;
        underlyingToken.mint(address(tipJar), initialBalance);

        vm.startPrank(address(tipJar));
        underlyingToken.approve(address(fleetCommander), initialBalance);
        fleetCommander.deposit(initialBalance, address(tipJar));
        vm.stopPrank();

        // Shake the jar
        tipJar.shake(fleetCommander);

        // Check balances
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 600 ether);
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            300 ether
        );
        assertEq(underlyingToken.balanceOf(treasury), 100 ether);
    }

    function test_ShakeMultiple() public {
        address anotherMockTipStreamParticipant = address(5);

        // Setup tip streams
        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(60),
            block.timestamp
        );
        tipJar.addTipStream(
            anotherMockTipStreamParticipant,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp
        );
        vm.stopPrank();

        // Create a second FleetCommander
        FleetCommanderMock fleetCommander2 = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            PercentageUtils.fromDecimalPercentage(1)
        );

        // Setup mock fleet commanders with some balance
        uint256 initialBalance = 1000 ether;
        underlyingToken.mint(address(tipJar), initialBalance * 2);

        vm.startPrank(address(tipJar));
        underlyingToken.approve(address(fleetCommander), initialBalance);
        underlyingToken.approve(address(fleetCommander2), initialBalance);
        fleetCommander.deposit(initialBalance, address(tipJar));
        fleetCommander2.deposit(initialBalance, address(tipJar));
        vm.stopPrank();

        // Shake multiple jars
        IFleetCommander[] memory commanders = new IFleetCommander[](2);
        commanders[0] = fleetCommander;
        commanders[1] = fleetCommander2;
        tipJar.shakeMultiple(commanders);

        // Check balances (should be doubled compared to the single shake test)
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 1200 ether);
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            600 ether
        );
        assertEq(underlyingToken.balanceOf(treasury), 200 ether);
    }

    function test_FailShakeWithNoShares() public {
        // Ensure the TipJar has no shares in the FleetCommander
        assertEq(fleetCommander.balanceOf(address(tipJar)), 0);

        vm.expectRevert(NoSharesToDistribute.selector);
        tipJar.shake(fleetCommander);
    }

    function test_FailRemoveNonexistentTipStream() public {
        address nonexistentRecipient = address(99);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                TipStreamDoesNotExist.selector,
                nonexistentRecipient
            )
        );
        tipJar.removeTipStream(nonexistentRecipient);
    }

    function test_FailSetInvalidTreasuryAddress() public {
        vm.prank(governor);
        vm.expectRevert(InvalidTreasuryAddress.selector);
        tipJar.setTreasuryAddress(address(0));
    }

    function test_FailAddTipStreamNonGovernor() public {
        address notGovernor = address(6);
        vm.prank(notGovernor);
        vm.expectRevert(
            abi.encodeWithSelector(CallerIsNotGovernor.selector, notGovernor)
        );
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp + 1 days
        );
    }

    function test_FailUpdateTipStreamBeforeMinTerm() public {
        vm.prank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp + 1 days
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSelector(
                TipStreamMinTermNotReached.selector,
                mockTipStreamRecipient
            )
        );
        tipJar.updateTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp + 2 days
        );
    }

    function test_FailExceedTotalAllocation() public {
        address anotherMockTipStreamParticipant = address(5);

        vm.startPrank(governor);
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(60),
            block.timestamp
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                TotalAllocationExceedsOneHundredPercent.selector
            )
        );
        tipJar.addTipStream(
            anotherMockTipStreamParticipant,
            PercentageUtils.fromDecimalPercentage(50),
            block.timestamp
        );
    }

    function test_SetTreasuryAddress() public {
        address newTreasury = address(6);

        vm.prank(governor);
        tipJar.setTreasuryAddress(newTreasury);
        assertEq(tipJar.treasuryAddress(), newTreasury);
    }
}

contract ConfigurationManagerImplMock is ConfigurationManagerMock {
    constructor(address _tipJar) ConfigurationManagerMock(_tipJar) {}

    function setTipJar(address newTipJar) external override {}
}
