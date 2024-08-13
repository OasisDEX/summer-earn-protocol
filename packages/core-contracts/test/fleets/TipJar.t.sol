// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {ITipJar} from "../../src/interfaces/ITipJar.sol";
import {ITipJarEvents} from "../../src/interfaces/ITipJarEvents.sol";

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
        assertEq(stream.lockedUntilEpoch, block.timestamp + 1 days);
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
        assertEq(stream.lockedUntilEpoch, block.timestamp + 3 days);
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
        assertEq(stream.lockedUntilEpoch, 0);
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
        tipJar.shake(address(fleetCommander));

        // Check balances
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 600 ether);
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            300 ether
        );
        assertEq(underlyingToken.balanceOf(treasury), 100 ether);
    }
    function test_ShakeWith100PercentAllocations() public {
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
            PercentageUtils.fromDecimalPercentage(40),
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
        tipJar.shake(address(fleetCommander));

        // Check balances
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 600 ether);
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            400 ether
        );
        assertEq(underlyingToken.balanceOf(treasury), 0 ether);
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
        address[] memory commanders = new address[](2);
        commanders[0] = address(fleetCommander);
        commanders[1] = address(fleetCommander2);
        tipJar.shakeMultiple(commanders);

        // Check balances (should be doubled compared to the single shake test)
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 1200 ether);
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            600 ether
        );
        assertEq(underlyingToken.balanceOf(treasury), 200 ether);
    }

    function test_ShakeWithAccruedInterest() public {
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

        // Simulate time passage and accrued interest
        vm.warp(block.timestamp + 30 days);
        uint256 interestRate = 5; // 5% interest
        uint256 accruedInterest = (initialBalance * interestRate) / 100;
        underlyingToken.mint(address(fleetCommander), accruedInterest);

        // Shake the jar
        tipJar.shake(address(fleetCommander));

        // Calculate expected amounts
        uint256 totalAmount = initialBalance + accruedInterest;
        uint256 expectedMockRecipientAmount = (totalAmount * 60) / 100;
        uint256 expectedAnotherRecipientAmount = (totalAmount * 30) / 100;
        uint256 expectedTreasuryAmount = totalAmount -
            expectedMockRecipientAmount -
            expectedAnotherRecipientAmount;

        // Check balances
        assertApproxEqRel(
            underlyingToken.balanceOf(mockTipStreamRecipient),
            expectedMockRecipientAmount,
            1
        );
        assertApproxEqRel(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            expectedAnotherRecipientAmount,
            1
        );
        assertApproxEqRel(
            underlyingToken.balanceOf(treasury),
            expectedTreasuryAmount,
            1
        );
    }

    function test_GetTotalAllocation() public {
        // Setup initial tip streams
        vm.startPrank(governor);
        tipJar.addTipStream(
            address(4),
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp
        );
        tipJar.addTipStream(
            address(5),
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp
        );
        vm.stopPrank();

        // Check initial total allocation
        Percentage totalAllocation = tipJar.getTotalAllocation();
        assertEq(fromPercentage(totalAllocation), 50);

        // Add another tip stream
        vm.prank(governor);
        tipJar.addTipStream(
            address(6),
            PercentageUtils.fromDecimalPercentage(25),
            block.timestamp
        );

        // Check updated total allocation
        totalAllocation = tipJar.getTotalAllocation();
        assertEq(fromPercentage(totalAllocation), 75);

        // Remove a tip stream
        vm.prank(governor);
        tipJar.removeTipStream(address(5));

        // Check final total allocation
        totalAllocation = tipJar.getTotalAllocation();
        assertEq(fromPercentage(totalAllocation), 45);
    }

    function test_FailShakeWithNoShares() public {
        // Ensure the TipJar has no assets in the FleetCommander
        assertEq(
            fleetCommander.convertToAssets(
                fleetCommander.balanceOf(address(tipJar))
            ),
            0
        );

        vm.expectRevert(NoSharesToRedeem.selector);
        tipJar.shake(address(fleetCommander));
    }

    function test_FailShakeWithNoAssets() public {
        fleetCommander.testMint(address(tipJar), 1 ether);

        vm.expectRevert(NoAssetsToDistribute.selector);
        tipJar.shake(address(fleetCommander));
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

    function test_FailShakeInvalidFleetCommanderAddress() public {
        vm.expectRevert(InvalidFleetCommanderAddress.selector);
        tipJar.shake(address(0));
    }

    function test_FailAddTipStreamWithInvalidAllocation() public {
        vm.startPrank(governor);

        // Test with zero allocation
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidTipStreamAllocation.selector,
                PercentageUtils.fromDecimalPercentage(0)
            )
        );
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(0),
            block.timestamp
        );

        // Test with allocation greater than 100%
        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidTipStreamAllocation.selector,
                PercentageUtils.fromDecimalPercentage(101)
            )
        );
        tipJar.addTipStream(
            mockTipStreamRecipient,
            PercentageUtils.fromDecimalPercentage(101),
            block.timestamp
        );

        vm.stopPrank();
    }

    function test_GetAllTipStreamsEmpty() public view {
        // Test when there are no tip streams
        ITipJar.TipStream[] memory emptyStreams = tipJar.getAllTipStreams();
        assertEq(emptyStreams.length, 0);
    }

    function test_GetAllTipStreamsMultiple() public {
        address recipient1 = address(4);
        address recipient2 = address(5);
        address recipient3 = address(6);

        vm.startPrank(governor);
        tipJar.addTipStream(
            recipient1,
            PercentageUtils.fromDecimalPercentage(20),
            block.timestamp
        );
        tipJar.addTipStream(
            recipient2,
            PercentageUtils.fromDecimalPercentage(30),
            block.timestamp
        );
        tipJar.addTipStream(
            recipient3,
            PercentageUtils.fromDecimalPercentage(10),
            block.timestamp
        );
        vm.stopPrank();

        ITipJar.TipStream[] memory allStreams = tipJar.getAllTipStreams();
        assertEq(allStreams.length, 3);
        assertEq(allStreams[0].recipient, recipient1);
        assertEq(allStreams[1].recipient, recipient2);
        assertEq(allStreams[2].recipient, recipient3);
        assertEq(fromPercentage(allStreams[0].allocation), 20);
        assertEq(fromPercentage(allStreams[1].allocation), 30);
        assertEq(fromPercentage(allStreams[2].allocation), 10);
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
                TipStreamLocked.selector,
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
