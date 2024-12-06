// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";

import {CooldownNotElapsed} from "../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";

import "../../src/events/IArkEvents.sol";
import "../../src/events/IFleetCommanderEvents.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import {IArkConfigProvider} from "../../src/interfaces/IArkConfigProvider.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {PERCENTAGE_100, Percentage, PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {console} from "forge-std/console.sol";
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

contract RebalanceTest is Test, TestHelpers, FleetCommanderTestBase {
    using Math for uint256;
    using PercentageUtils for uint256;

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

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), rebalanceAmount);

        fleetCommander.rebalance(rebalanceData);

        // Assert
        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(
            config.bufferArk.totalAssets(),
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

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
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
        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(
            config.bufferArk.totalAssets(),
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

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(address(bufferArkAddress), initialBufferBalance);
        mockToken.mint(ark1, ark1IntitialBalance);
        mockToken.mint(ark2, ark2IntitialBalance);
        mockToken.mint(ark3, ark3IntitialBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: ark3,
            amount: 500 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.rebalance(rebalanceData);

        // Assert
        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(
            config.bufferArk.totalAssets(),
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
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
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
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
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
                ark2
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedMaxAllocation() public {
        // Arrange
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, ARK2_MAX_ALLOCATION); // Already at max allocation

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
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
                ark2,
                1000000000,
                15000000000
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

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
            amount: rebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderEffectiveDepositCapExceeded(address,uint256,uint256)",
                ark2,
                1000000000,
                15000000000
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
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
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
        RebalanceData[] memory rebalanceData = new RebalanceData[](50 + 1);

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderRebalanceTooManyOperations(uint256)",
                50 + 1
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
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
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
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
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

    function test_forceRebalanceToBufferArk() public {
        mockToken.mint(ark1, 1000000000000000);
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: bufferArkAddress,
            amount: 1000 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(governor);
        fleetCommander.forceRebalance(rebalanceData);
    }

    function test_rebalanceFromBufferArk() public {
        mockToken.mint(bufferArkAddress, 1000000000000000);
        // Arrange
        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: 10 * 10 ** 6,
            boardData: bytes(""),
            disembarkData: bytes("")
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(governor);
        fleetCommander.forceRebalance(rebalanceData);
    }

    function test_ForceRebalance() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;

        fleetCommanderStorageWriter.setminimumBufferBalance(minBufferBalance);

        mockToken.mint(bufferArkAddress, initialBufferBalance);
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
            amount: rebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(governor);
        vm.expectEmit();
        emit IArkEvents.Moved(ark1, ark2, address(mockToken), rebalanceAmount);

        fleetCommander.forceRebalance(rebalanceData);

        // Assert
        FleetConfig memory config = fleetCommander.getConfig();
        assertEq(
            config.bufferArk.totalAssets(),
            initialBufferBalance,
            "Buffer balance should remain unchanged"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance + 10000 * 10 ** 6,
            "Total assets should remain unchanged"
        );
    }

    function test_RebalanceExceedsMoveMaxRebalanceOutflow() public {
        // Arrange
        uint256 maxRebalanceOutflow = 500 * 10 ** 6;
        uint256 rebalanceAmount = 1000 * 10 ** 6;
        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);

        mockArkMaxRebalanceOutflow(ark1, maxRebalanceOutflow);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
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

        _mockArkMoveToMax(ark2, maxRebalanceInflow);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            amount: rebalanceAmount,
            boardData: bytes(""),
            disembarkData: bytes("")
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

    function test_GetEffectiveDepositCap() public {
        // Arrange
        uint256 totalAssets = 1000000 * 10 ** 6; // 1,000,000 tokens
        uint256 arkDepositCap = 200000 * 10 ** 6; // 200,000 tokens
        Percentage maxDepositPercentageOfTVL = PercentageUtils.fromFraction(
            30,
            100
        ); // 30% -> 300,000 tokens

        // Mock total assets
        vm.mockCall(
            address(fleetCommander),
            abi.encodeWithSelector(fleetCommander.totalAssets.selector),
            abi.encode(totalAssets)
        );

        // Mock ark deposit cap
        vm.mockCall(
            ark1,
            abi.encodeWithSelector(IArkConfigProvider.depositCap.selector),
            abi.encode(arkDepositCap)
        );

        // Mock ark max deposit percentage of TVL
        vm.mockCall(
            ark1,
            abi.encodeWithSelector(
                IArkConfigProvider.maxDepositPercentageOfTVL.selector
            ),
            abi.encode(maxDepositPercentageOfTVL)
        );

        // Act
        uint256 effectiveDepositCap = fleetCommander.getEffectiveArkDepositCap(
            IArk(ark1)
        );

        // Assert
        uint256 expectedCap = Math.min(
            totalAssets.applyPercentage(maxDepositPercentageOfTVL),
            arkDepositCap
        );
        console.log("expectedCap", expectedCap);
        assertEq(
            effectiveDepositCap,
            expectedCap,
            "Effective deposit cap should be the minimum of percentage-based and absolute caps"
        );
    }

    function test_GetEffectiveDepositCap_2() public {
        // Arrange
        uint256 totalAssets = 1000000 * 10 ** 6; // 1,000,000 tokens
        uint256 arkDepositCap = 400000 * 10 ** 6; // 400,000 tokens
        Percentage maxDepositPercentageOfTVL = PercentageUtils.fromFraction(
            30,
            100
        ); // 30% -> 300,000 tokens

        // Mock total assets
        vm.mockCall(
            address(fleetCommander),
            abi.encodeWithSelector(fleetCommander.totalAssets.selector),
            abi.encode(totalAssets)
        );

        // Mock ark deposit cap
        vm.mockCall(
            ark1,
            abi.encodeWithSelector(IArkConfigProvider.depositCap.selector),
            abi.encode(arkDepositCap)
        );

        // Mock ark max deposit percentage of TVL
        vm.mockCall(
            ark1,
            abi.encodeWithSelector(
                IArkConfigProvider.maxDepositPercentageOfTVL.selector
            ),
            abi.encode(maxDepositPercentageOfTVL)
        );

        // Act
        uint256 effectiveDepositCap = fleetCommander.getEffectiveArkDepositCap(
            IArk(ark1)
        );

        // Assert
        uint256 expectedCap = Math.min(
            totalAssets.applyPercentage(maxDepositPercentageOfTVL),
            arkDepositCap
        );
        console.log("expectedCap", expectedCap);
        assertEq(
            effectiveDepositCap,
            expectedCap,
            "Effective deposit cap should be the minimum of percentage-based and absolute caps"
        );
    }

    function test_RebalanceWithEffectiveDepositCap() public {
        // Arrange
        uint256 totalAssets = 1000000 * 10 ** 6; // 1,000,000 tokens
        uint256 arkDepositCap = 500000 * 10 ** 6; // 500,000 tokens
        Percentage maxDepositPercentageOfTVL = PercentageUtils.fromFraction(
            30,
            100
        ); // 30%
        uint256 rebalanceAmount = 400000 * 10 ** 6; // 400,000 tokens (exceeds effective cap)

        // Mock total assets
        vm.mockCall(
            address(fleetCommander),
            abi.encodeWithSelector(fleetCommander.totalAssets.selector),
            abi.encode(totalAssets)
        );

        // Set up ark1 and ark2
        mockToken.mint(ark1, 500000 * 10 ** 6);
        mockToken.mint(ark2, 100000 * 10 ** 6);

        // Mock ark deposit cap and max deposit percentage for ark2
        vm.mockCall(
            ark2,
            abi.encodeWithSelector(IArkConfigProvider.depositCap.selector),
            abi.encode(arkDepositCap)
        );
        vm.mockCall(
            ark2,
            abi.encodeWithSelector(
                IArkConfigProvider.maxDepositPercentageOfTVL.selector
            ),
            abi.encode(maxDepositPercentageOfTVL)
        );

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
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
                ark2,
                400000 * 10 ** 6,
                300000 * 10 ** 6
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }

    function test_RebalanceExceedsMoveMaxRebalanceOutflow_MultipleOperations()
        public
    {
        // Arrange
        uint256 maxRebalanceOutflow = 500 * 10 ** 6;
        uint256 rebalanceAmount1 = 300 * 10 ** 6;
        uint256 rebalanceAmount2 = 300 * 10 ** 6; // Total 600M > maxRebalanceOutflow

        mockToken.mint(ark1, 5000 * 10 ** 6);
        mockToken.mint(ark2, 5000 * 10 ** 6);
        mockToken.mint(ark3, 5000 * 10 ** 6);

        mockArkMaxRebalanceOutflow(ark1, maxRebalanceOutflow);

        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1,
            toArk: ark2,
            boardData: bytes(""),
            disembarkData: bytes(""),
            amount: rebalanceAmount1
        });
        rebalanceData[1] = RebalanceData({
            fromArk: ark1,
            toArk: ark3,
            boardData: bytes(""),
            disembarkData: bytes(""),
            amount: rebalanceAmount2
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderExceedsMaxOutflow(address,uint256,uint256)",
                ark1,
                rebalanceAmount1 + rebalanceAmount2,
                maxRebalanceOutflow
            )
        );
        fleetCommander.rebalance(rebalanceData);
    }
}
