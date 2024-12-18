// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ITipJarEvents} from "../../src/events/ITipJarEvents.sol";
import {ITipJar} from "../../src/interfaces/ITipJar.sol";
import {FleetCommanderMock} from "../mocks/FleetCommanderMock.sol";
import {Test, console} from "forge-std/Test.sol";

import {TipJar} from "../../src/contracts/TipJar.sol";
import {ProtocolAccessManager} from "@summerfi/access-contracts/contracts/ProtocolAccessManager.sol";

import {HarborCommand} from "../../src/contracts/HarborCommand.sol";

import "../../src/errors/ITipJarErrors.sol";

import {ConfigurationManagerImplMock, ConfigurationManagerMock} from "../mocks/ConfigurationManagerMock.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@summerfi/access-contracts/interfaces/IAccessControlErrors.sol";
import {ContractSpecificRoles} from "@summerfi/access-contracts/interfaces/IProtocolAccessManager.sol";
import {Percentage, fromPercentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract TipJarTest is Test, ITipJarEvents {
    using PercentageUtils for uint256;

    address public governor = address(1);
    address public guardian = address(1);
    address public keeper = address(2);
    address public treasury = address(3);
    address public mockTipStreamRecipient = address(4);

    FleetCommanderMock public fleetCommander;
    ConfigurationManagerMock public configManager;
    ERC20Mock public underlyingToken;
    TipJar public tipJar;
    ProtocolAccessManager public accessManager;
    HarborCommand public harborCommand;

    function setUp() public {
        accessManager = new ProtocolAccessManager(governor);
        vm.prank(governor);
        accessManager.grantContractSpecificRole(
            ContractSpecificRoles.KEEPER_ROLE,
            address(0),
            keeper
        );
        harborCommand = new HarborCommand(address(accessManager));

        underlyingToken = new ERC20Mock();
        configManager = new ConfigurationManagerImplMock(
            address(tipJar),
            treasury,
            address(0),
            address(harborCommand),
            address(0)
        );

        Percentage initialTipRate = PercentageUtils.fromIntegerPercentage(1); // 1%
        fleetCommander = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            initialTipRate
        );

        tipJar = new TipJar(address(accessManager), address(configManager));
        configManager.setTipRate(100); // 1%

        vm.prank(address(fleetCommander));
        underlyingToken.approve(address(fleetCommander), type(uint256).max);

        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(fleetCommander));
    }

    function test_AddTipStream() public {
        vm.prank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );

        ITipJar.TipStream memory stream = tipJar.getTipStream(
            mockTipStreamRecipient
        );
        assertEq(stream.recipient, mockTipStreamRecipient);
        assertTrue(
            stream.allocation == PercentageUtils.fromIntegerPercentage(20)
        );
        assertEq(stream.lockedUntilEpoch, block.timestamp + 1 days);
    }

    function test_AddAnExistingStream() public {
        vm.prank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );
        vm.expectRevert(
            abi.encodeWithSignature(
                "TipStreamAlreadyExists(address)",
                mockTipStreamRecipient
            )
        );
        vm.prank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );
    }

    function test_UpdateTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );

        vm.warp(block.timestamp + 2 days);
        tipJar.updateTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp + 3 days
            }),
            false
        );

        vm.stopPrank();

        ITipJar.TipStream memory stream = tipJar.getTipStream(address(4));
        assertEq(stream.recipient, mockTipStreamRecipient);
        assertEq(fromPercentage(stream.allocation), 60);
        assertEq(stream.lockedUntilEpoch, block.timestamp + 3 days);
    }

    function test_RemoveTipStream() public {
        vm.startPrank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
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

    function test_FailAddTipStreamWithZeroAddress() public {
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("InvalidTipStreamRecipient()"));
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: address(0),
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );
    }

    function test_GetAllTipStreams() public {
        address anotherMockTipStreamParticipant = address(5);
        vm.startPrank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp + 2 days
            })
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
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
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
        assertEq(IERC20(fleetCommander).balanceOf(address(tipJar)), 0 ether);
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
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(40),
                lockedUntilEpoch: block.timestamp
            })
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
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
        );
        vm.stopPrank();

        // Create a second FleetCommander
        FleetCommanderMock fleetCommander2 = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            PercentageUtils.fromIntegerPercentage(1)
        );
        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(fleetCommander2));

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
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
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
            ITipJar.TipStream({
                recipient: address(4),
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: address(5),
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
        );
        vm.stopPrank();

        // Check initial total allocation
        Percentage totalAllocation = tipJar.getTotalAllocation();
        assertEq(fromPercentage(totalAllocation), 50);

        // Add another tip stream
        vm.prank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: address(6),
                allocation: PercentageUtils.fromIntegerPercentage(25),
                lockedUntilEpoch: block.timestamp
            })
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

    function test_ShakeWithNoShares() public {
        // Ensure the TipJar has no assets in the FleetCommander
        assertEq(
            fleetCommander.convertToAssets(
                fleetCommander.balanceOf(address(tipJar))
            ),
            0
        );

        vm.expectEmit(true, true, true, true);
        emit TipJarShaken(address(fleetCommander), 0);
        tipJar.shake(address(fleetCommander));
    }

    function test_ShakeWithNoAssets() public {
        fleetCommander.testMint(address(tipJar), 1 ether);

        vm.expectEmit(true, true, true, true);
        emit TipJarShaken(address(fleetCommander), 0);
        tipJar.shake(address(fleetCommander));
    }

    function test_FailRemoveNonexistentTipStream() public {
        address nonexistentRecipient = address(99);

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "TipStreamDoesNotExist(address)",
                nonexistentRecipient
            )
        );
        tipJar.removeTipStream(nonexistentRecipient);
    }

    function test_FailShakeInvalidFleetCommanderAddress() public {
        vm.expectRevert(
            abi.encodeWithSignature("InvalidFleetCommanderAddress()")
        );
        tipJar.shake(address(0));
    }

    function test_FailAddTipStreamWithInvalidAllocation() public {
        vm.startPrank(governor);

        // Test with zero allocation
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTipStreamAllocation(uint256)",
                PercentageUtils.fromIntegerPercentage(0)
            )
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(0),
                lockedUntilEpoch: block.timestamp
            })
        );

        // Test with allocation greater than 100%
        vm.expectRevert(
            abi.encodeWithSignature(
                "InvalidTipStreamAllocation(uint256)",
                PercentageUtils.fromIntegerPercentage(101)
            )
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(101),
                lockedUntilEpoch: block.timestamp
            })
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
            ITipJar.TipStream({
                recipient: recipient1,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: recipient2,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: recipient3,
                allocation: PercentageUtils.fromIntegerPercentage(10),
                lockedUntilEpoch: block.timestamp
            })
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
            abi.encodeWithSignature("CallerIsNotGovernor(address)", notGovernor)
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );
    }

    function test_FailUpdateTipStreamBeforeMinTerm() public {
        vm.prank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(20),
                lockedUntilEpoch: block.timestamp + 1 days
            })
        );

        vm.prank(governor);
        vm.expectRevert(
            abi.encodeWithSignature(
                "TipStreamLocked(address)",
                mockTipStreamRecipient
            )
        );
        tipJar.updateTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp + 2 days
            }),
            false
        );
    }

    function test_FailExceedTotalAllocation() public {
        address anotherMockTipStreamParticipant = address(5);

        vm.startPrank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        vm.expectRevert(
            abi.encodeWithSignature("TotalAllocationExceedsOneHundredPercent()")
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(50),
                lockedUntilEpoch: block.timestamp
            })
        );
    }

    function test_UpdateTipStreamWithGlobalShake() public {
        address anotherMockTipStreamParticipant = address(5);

        // Setup initial tip streams
        vm.startPrank(governor);
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(60),
                lockedUntilEpoch: block.timestamp
            })
        );
        tipJar.addTipStream(
            ITipJar.TipStream({
                recipient: anotherMockTipStreamParticipant,
                allocation: PercentageUtils.fromIntegerPercentage(30),
                lockedUntilEpoch: block.timestamp
            })
        );
        vm.stopPrank();

        // Create a second FleetCommander
        FleetCommanderMock fleetCommander2 = new FleetCommanderMock(
            address(underlyingToken),
            address(configManager),
            PercentageUtils.fromIntegerPercentage(1)
        );
        vm.prank(governor);
        harborCommand.enlistFleetCommander(address(fleetCommander2));

        // Setup mock fleet commanders with some balance
        uint256 initialBalance = 1000 ether;
        underlyingToken.mint(address(tipJar), initialBalance * 2);

        vm.startPrank(address(tipJar));
        underlyingToken.approve(address(fleetCommander), type(uint256).max);
        underlyingToken.approve(address(fleetCommander2), type(uint256).max);
        fleetCommander.deposit(initialBalance, address(tipJar));
        fleetCommander2.deposit(initialBalance, address(tipJar));
        vm.stopPrank();

        // Update tip stream with global shake
        vm.prank(governor);
        tipJar.updateTipStream(
            ITipJar.TipStream({
                recipient: mockTipStreamRecipient,
                allocation: PercentageUtils.fromIntegerPercentage(70),
                lockedUntilEpoch: block.timestamp + 1 days
            }),
            true // Perform global shake
        );

        // Check balances after global shake and update
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 1200 ether); // 60% of 2000 ether
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            600 ether
        ); // 30% of 2000 ether
        assertEq(underlyingToken.balanceOf(treasury), 200 ether); // 10% of 2000 ether

        // Verify the tip stream was updated
        ITipJar.TipStream memory updatedStream = tipJar.getTipStream(
            mockTipStreamRecipient
        );
        assertEq(fromPercentage(updatedStream.allocation), 70);
        assertEq(updatedStream.lockedUntilEpoch, block.timestamp + 1 days);

        // Setup another balance to test the new allocation
        underlyingToken.mint(address(tipJar), initialBalance);
        vm.startPrank(address(tipJar));
        underlyingToken.approve(address(fleetCommander), initialBalance);
        fleetCommander.deposit(initialBalance, address(tipJar));
        vm.stopPrank();

        // Shake again to test new allocation
        tipJar.shake(address(fleetCommander));

        // Check final balances
        assertEq(underlyingToken.balanceOf(mockTipStreamRecipient), 1900 ether); // 1200 + (70% of 1000)
        assertEq(
            underlyingToken.balanceOf(anotherMockTipStreamParticipant),
            900 ether
        ); // 600 + (30% of 1000)
        assertEq(underlyingToken.balanceOf(treasury), 200 ether); // Unchanged as 100% allocated to streams
    }
}
