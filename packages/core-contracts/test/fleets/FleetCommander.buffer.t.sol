// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {FleetConfig, RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

/**
 * @title Buffer test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's fund buffer functionality
 *
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Buffer adjustment
 * - Error cases and edge scenarios
 */
contract BufferTest is Test, TestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function test_AdjustBufferSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;
        uint256 ark2RebalanceAmount = 2000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        // Get the bufferArk from FleetCommander config
        FleetConfig memory config = fleetCommander.getConfig();

        // Mock token balance
        mockToken.mint(address(config.bufferArk), initialBufferBalance);

        // Mock Ark behavior

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark1,
            amount: ark1RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark2,
            amount: ark2RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN + 1);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.arks(0)).totalAssets(),
            ark1RebalanceAmount,
            "Ark1 should have ark1RebalanceAmount assets"
        );
        assertEq(
            IArk(fleetCommander.arks(1)).totalAssets(),
            ark2RebalanceAmount,
            "Ark2 should have ark2RebalanceAmount assets"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );

        // Prepare rebalance data for moving funds back to buffer
        RebalanceData[] memory rebalanceFromData = new RebalanceData[](2);
        rebalanceFromData[0] = RebalanceData({
            fromArk: ark1,
            toArk: address(config.bufferArk),
            amount: ark1RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceFromData[1] = RebalanceData({
            fromArk: ark2,
            toArk: address(config.bufferArk),
            amount: ark2RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act round 2
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceFromData);

        // Assert round 2
        assertEq(
            config.bufferArk.totalAssets(),
            initialBufferBalance,
            "Buffer balance should be equal to initialBufferBalance - all funds moved back to buffer"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
        assertEq(IArk(ark1).totalAssets(), 0, "Ark1 should have no assets");
        assertEq(IArk(ark2).totalAssets(), 0, "Ark2 should have no assets");
    }

    function test_AdjustBufferMovingMoreThanAllowed() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        // Mock Ark behavior

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: ark1RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark2,
            amount: ark1RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderInsufficientBuffer()")
        );
        fleetCommander.rebalance(rebalanceData);
        vm.stopPrank();
    }

    function test_AdjustBufferNoExcessFunds() public {
        // Arrange
        uint256 bufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(bufferArkAddress),
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderNoExcessFunds()")
        );
        fleetCommander.rebalance(rebalanceData);
        vm.stopPrank();
    }

    function test_AdjustBufferAndRebalance() public {
        // Arrange
        uint256 bufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(address(bufferArkAddress), bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark2,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark2,
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        assertEq(
            fleetCommander.totalAssets(),
            bufferBalance,
            "Total assets should be equal to bufferBalance - 1000 * 10 ** 6"
        );
        assertEq(
            mockArk1.totalAssets(),
            1000 * 10 ** 6,
            "Ark1 should have 1000 * 10 ** 6 assets"
        );
        assertEq(mockArk2.totalAssets(), 0, "Ark2 should have 0 assets");
    }

    function test_AdjustBufferInvalidTargetArk() public {
        // Arrange
        uint256 ark2Balance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(address(ark2), ark2Balance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark2,
            toArk: bufferArkAddress,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark2,
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);
        assertEq(
            fleetCommander.totalAssets(),
            ark2Balance,
            "Total assets should be equal to initial ark2Balance"
        );
        assertEq(
            mockArk1.totalAssets(),
            1000 * 10 ** 6,
            "Ark1 should have 1000 * 10 ** 6 assets"
        );
        assertEq(
            mockArk2.totalAssets(),
            ark2Balance - 2000 * 10 ** 6,
            "Ark2 should have ark2Balance - 2000 * 10 ** 6 assets"
        );
    }

    function test_AdjustBufferPartialMove() public {
        // Arrange
        uint256 initialBufferBalance = 12000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: ark1RebalanceAmount, // More than excess funds,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderInsufficientBuffer()")
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferWithMultipleArks() public {
        // Arrange
        uint256 initialBufferBalance = 20000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;
        uint256 ark2RebalanceAmount = 2000 * 10 ** 6;
        uint256 ark3RebalanceAmount = 1000 * 10 ** 6;

        FleetConfig memory config = fleetCommander.getConfig();

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(config.bufferArk), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](3);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark1,
            amount: ark1RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark2,
            amount: ark2RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[2] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark3,
            amount: ark3RebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            config.bufferArk.totalAssets(),
            initialBufferBalance -
                ark1RebalanceAmount -
                ark2RebalanceAmount -
                ark3RebalanceAmount
        );
        assertEq(mockArk1.totalAssets(), ark1RebalanceAmount);
        assertEq(mockArk2.totalAssets(), ark2RebalanceAmount);
        assertEq(mockArk3.totalAssets(), ark3RebalanceAmount);
    }

    function test_AdjustBufferWithMaximumAllowedAmount() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 maxRebalanceAmount = initialBufferBalance - minBufferBalance;

        FleetConfig memory config = fleetCommander.getConfig();

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(config.bufferArk), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark1,
            amount: maxRebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(config.bufferArk.totalAssets(), minBufferBalance);
        assertEq(mockArk1.totalAssets(), maxRebalanceAmount);
    }

    function test_AdjustBufferAtMinimumBalance() public {
        // Arrange
        uint256 initialBufferBalance = 10000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderNoExcessFunds()")
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferWithZeroAmount() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 0,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceAmountZero(address)",
                ark1
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferAsNonKeeper() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(address(0xdeadbeef)); // Non-keeper address
        vm.expectRevert(
            abi.encodeWithSignature(
                "CallerIsNotKeeper(address)",
                address(0xdeadbeef)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferWithArkAtMaxAllocation() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1MaxAllocation = 5000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        _mockArkMaxAllocation(ark1, ark1MaxAllocation);
        mockToken.mint(address(ark1), ark1MaxAllocation);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderEffectiveDepositCapExceeded(address,uint256,uint256)",
                ark1,
                1000000000,
                5000 * 10 ** 6
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferFromBufferWithMaxUint_ShouldFail() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1MaxAllocation = 5000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        _mockArkMaxAllocation(ark1, ark1MaxAllocation);
        mockToken.mint(address(ark1), ark1MaxAllocation);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: type(uint256).max,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantUseMaxUintMovingFromBuffer()"
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferToBufferWithMaxUint_ShouldFail() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1MaxAllocation = 5000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        _mockArkMaxAllocation(ark1, ark1MaxAllocation);
        mockToken.mint(address(ark1), ark1MaxAllocation);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: bufferArkAddress,
            amount: type(uint256).max,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferFromMultipleArksToBufferWithMaxUint() public {
        // Arrange
        uint256 initialBufferBalance = 10000 * 10 ** 6;
        uint256 ark1Balance = 5000 * 10 ** 6;
        uint256 ark2Balance = 3000 * 10 ** 6;
        uint256 minBufferBalance = 5000 * 10 ** 6;

        FleetConfig memory config = fleetCommander.getConfig();

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(config.bufferArk), initialBufferBalance);
        mockToken.mint(ark1, ark1Balance);
        mockToken.mint(ark2, ark2Balance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: address(config.bufferArk),
            amount: type(uint256).max,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark2,
            toArk: address(config.bufferArk),
            amount: type(uint256).max,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        uint256 expectedFinalBufferBalance = initialBufferBalance +
            ark1Balance +
            ark2Balance;

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        // Verify events
        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderEvents.Rebalanced(keeper, rebalanceData);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            config.bufferArk.totalAssets(),
            expectedFinalBufferBalance,
            "Buffer balance should include all funds from ark1 and ark2"
        );
        assertEq(IArk(ark1).totalAssets(), 0, "Ark1 should have no assets");
        assertEq(IArk(ark2).totalAssets(), 0, "Ark2 should have no assets");
        assertEq(
            fleetCommander.totalAssets(),
            expectedFinalBufferBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_AdjustBufferWithAmountExceedingMaxAllocation() public {
        uint256 rebalanceAmount = 1000 * 10 ** 6;
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1MaxAllocation = 5000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        _mockArkMaxAllocation(ark1, ark1MaxAllocation);
        // Max allocation is one unit less than the rebalance amount
        mockToken.mint(address(ark1), ark1MaxAllocation - rebalanceAmount + 1);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderEffectiveDepositCapExceeded(address,uint256,uint256)",
                ark1,
                1000000000,
                5000 * 10 ** 6
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_AdjustBufferEventEmission() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 2000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderEvents.Rebalanced(keeper, rebalanceData);
        fleetCommander.rebalance(rebalanceData);
    }

    function test_TotalAssetsConsistencyAfterBufferAdjustment() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 2000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        FleetConfig memory config = fleetCommander.getConfig();

        mockToken.mint(address(config.bufferArk), initialBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark1,
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        uint256 initialTotalAssets = fleetCommander.totalAssets();

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        uint256 finalTotalAssets = fleetCommander.totalAssets();
        assertEq(
            initialTotalAssets,
            finalTotalAssets,
            "Total assets should remain consistent after buffer adjustment"
        );
    }

    function test_AdjustBufferMoveToArkAndBackToBuffer() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 6500 * 10 ** 6;

        FleetConfig memory config = fleetCommander.getConfig();

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);
        mockToken.mint(address(config.bufferArk), initialBufferBalance);

        // Prepare rebalance data to move from buffer to ark1 and back
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(config.bufferArk),
            toArk: ark1,
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: address(config.bufferArk),
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            config.bufferArk.totalAssets(),
            initialBufferBalance,
            "Buffer balance should be back to initial amount"
        );
        assertEq(
            IArk(ark1).totalAssets(),
            0,
            "Ark1 should have no assets after moving funds back"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }
}
