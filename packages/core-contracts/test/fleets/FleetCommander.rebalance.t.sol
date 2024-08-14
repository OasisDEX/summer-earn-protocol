// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";

import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";

import {CooldownNotElapsed} from "../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";

import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import "../../src/events/IArkEvents.sol";
import "../../src/events/IFleetCommanderEvents.sol";

/**
 * @title Rebalance test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's rebalance functionality
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Rebalancing operations
 * - Error cases and edge scenarios
 */
contract RebalanceTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
        vm.stopPrank();
    }

    function test_RebalanceSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), rebalanceAmount);

        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance + 10000 * 10 ** 6,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceWithMaxUint() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = type(uint256).max;

        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), 5000 * 10 ** 6);
        vm.expectEmit();
        emit IFleetCommanderEvents.Rebalanced(address(keeper), rebalanceData);

        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance + 10000 * 10 ** 6,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceMultipleArks() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        uint256 ark1IntitialBalance = 5000 * 10 ** 6;
        uint256 ark2IntitialBalance = 2500 * 10 ** 6;
        uint256 ark3IntitialBalance = 2500 * 10 ** 6;

        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(address(bufferArkAddress), initialBufferBalance);
        mockToken.mint(ark1, ark1IntitialBalance);
        mockToken.mint(ark2, ark2IntitialBalance);
        mockToken.mint(ark3, ark3IntitialBalance);

        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);
        mockArkRate(ark3, 115);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: ark3,
            amount: 500 * 10 ** 6
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance +
                ark1IntitialBalance +
                ark2IntitialBalance +
                ark3IntitialBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceInvalidSourceArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: invalidArk, // Invalid source
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotActive(address)",
                invalidArk
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceInvalidTargetArk() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: address(this), // Invalid target
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotActive(address)",
                address(this)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceZeroAmount() public {
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 0 // Zero amount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceAmountZero(address)",
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedMaxAllocation() public {
        // Arrange
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, ARK2_MAX_ALLOCATION); // Already at max allocation
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantRebalanceToArk(address)",
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedMaxAllocationAfterDeposit() public {
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        // Arrange
        mockToken.mint(ark1, 5000 * 10 ** 6);
        // Max allocation is one unit less than the rebalance amount
        mockToken.mint(ark2, ARK2_MAX_ALLOCATION - rebalanceAmount + 1);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantRebalanceToArk(address)",
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceLowerRate() public {
        // Arrange
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark2,
                105,
                110
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceCooldownNotElapsed() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });
        mockToken.mint(ark1, 5000 * 10 ** 6);

        // First rebalance
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        uint256 cooldown = 1 days;
        vm.prank(governor);
        fleetCommander.updateRebalanceCooldown(cooldown);

        // Try to rebalance again immediately
        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                fleetCommander.getLastActionTimestamp(),
                cooldown,
                block.timestamp
            )
        );

        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Advance time and try again
        vm.warp(block.timestamp + cooldown + 1);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData); // This should succeed
    }

    function test_FleetCommanderRebalanceNoOperations() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](0);

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature("FleetCommanderRebalanceNoOperations()")
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_FleetCommanderRebalanceTooManyOperations() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](10 + 1);

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceTooManyOperations(uint256)",
                10 + 1
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_TargetArkAddressZero() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: address(0), // Invalid target
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_SourceArkAddressZero() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(0), // Invalid target
            toArk: ark1,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderArkNotFound(address)",
                address(0)
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_rebalanceToBufferArk_ShouldFail() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: bufferArkAddress,
            amount: 1000 * 10 ** 6
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantUseRebalanceOnBufferArk()"
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_rebalanceFromBufferArk() public {
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 1000 * 10 ** 6
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderCantUseRebalanceOnBufferArk()"
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_ForceRebalance() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(governor);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), rebalanceAmount);

        fleetCommander.forceRebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance + 10000 * 10 ** 6,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceLowerRateWithOverAllocation() public {
        // Arrange
        uint256 arkMaxAllocation = 5000 * 10 ** 6;
        uint256 arkTotalAssets = 6000 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        mockArkMaxAllocation(ark1, arkMaxAllocation);
        mockToken.mint(ark1, arkTotalAssets);
        mockToken.mint(ark2, 4000 * 10 ** 6);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData); // This should succeed

        // Assert
        assertEq(
            IArk(ark1).totalAssets(),
            arkTotalAssets - rebalanceAmount,
            "Source ark balance should decrease"
        );
        assertEq(
            IArk(ark2).totalAssets(),
            4000 * 10 ** 6 + rebalanceAmount,
            "Target ark balance should increase"
        );
    }

    function test_RebalanceLowerRateWithOverAllocationExceedingAmount() public {
        // Arrange
        uint256 arkMaxAllocation = 5000 * 10 ** 6;
        uint256 arkTotalAssets = 6000 * 10 ** 6;
        uint256 rebalanceAmount = 1100 * 10 ** 6; // Exceeds over-allocation amount

        mockArkMaxAllocation(ark1, arkMaxAllocation);
        mockToken.mint(ark1, arkTotalAssets);
        mockToken.mint(ark2, 4000 * 10 ** 6);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark2,
                105,
                110
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceLowerRateWithoutOverAllocation() public {
        // Arrange
        uint256 arkMaxAllocation = 5000 * 10 ** 6;
        uint256 arkTotalAssets = 5000 * 10 ** 6; // Not over-allocated
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        mockArkMaxAllocation(ark1, arkMaxAllocation);
        mockToken.mint(ark1, arkTotalAssets);
        mockToken.mint(ark2, 4000 * 10 ** 6);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than source

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark2,
                105,
                110
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceMultipleOperationsWithMixedRates() public {
        // Arrange
        uint256 arkMaxAllocation = 5000 * 10 ** 6;
        uint256 ark1TotalAssets = 6000 * 10 ** 6; // Over-allocated
        uint256 ark2TotalAssets = 4000 * 10 ** 6;
        uint256 ark3TotalAssets = 3000 * 10 ** 6;

        mockArkMaxAllocation(ark1, arkMaxAllocation);
        mockToken.mint(ark1, ark1TotalAssets);
        mockToken.mint(ark2, ark2TotalAssets);
        mockToken.mint(ark3, ark3TotalAssets);
        mockArkRate(ark1, 110);
        mockArkRate(ark2, 105); // Lower rate than ark1
        mockArkRate(ark3, 115); // Higher rate than ark1

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 500 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: ark3,
            amount: 500 * 10 ** 6
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        assertEq(
            IArk(ark1).totalAssets(),
            ark1TotalAssets - 1000 * 10 ** 6,
            "Source ark balance should decrease"
        );
        assertEq(
            IArk(ark2).totalAssets(),
            ark2TotalAssets + 500 * 10 ** 6,
            "Lower rate ark balance should increase"
        );
        assertEq(
            IArk(ark3).totalAssets(),
            ark3TotalAssets + 500 * 10 ** 6,
            "Higher rate ark balance should increase"
        );
    }
    function test_RebalanceExceedsMoveMaxRebalanceOutflow() public {
        // Arrange
        uint256 maxRebalanceOutflow = 500 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);
        mockArkMaxRebalanceOutflow(ark1, maxRebalanceOutflow);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderExceedsMaxOutflow(address,uint256,uint256)",
                ark1,
                rebalanceAmount,
                maxRebalanceOutflow
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedsMoveToMax() public {
        // Arrange
        uint256 maxRebalanceInflow = 500 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);
        mockArkMoveToMax(ark2, maxRebalanceInflow);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderExceedsMaxInflow(address,uint256,uint256)",
                ark2,
                rebalanceAmount,
                maxRebalanceInflow
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceMinimumRateDifference() public {
        // Arrange
        uint256 rebalanceAmount = 1000 * 10 ** 6;
        uint256 lowRate = 105 * 10 ** 25; // 105%
        uint256 highRate = 106 * 10 ** 25; // 106% (1% difference)

        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, lowRate);
        mockArkRate(ark2, highRate);
        vm.prank(governor);
        fleetCommander.setMinimumRateDifference(
            PercentageUtils.fromIntegerPercentage(2)
        );

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderTargetArkRateTooLow(address,uint256,uint256)",
                ark2,
                highRate,
                lowRate
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceSuccessWithValidRateDifference() public {
        // Arrange
        uint256 rebalanceAmount = 1000 * 10 ** 6;
        uint256 lowRate = 100 * 10 ** 25; // 100%
        uint256 highRate = 105 * 10 ** 25; // 105% (5% difference, should be above minimum)

        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockArkRate(ark1, lowRate);
        mockArkRate(ark2, highRate);
        vm.prank(governor);
        fleetCommander.setMinimumRateDifference(
            PercentageUtils.fromIntegerPercentage(2)
        );

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), rebalanceAmount);

        fleetCommander.rebalance(rebalanceData);
    }
}
