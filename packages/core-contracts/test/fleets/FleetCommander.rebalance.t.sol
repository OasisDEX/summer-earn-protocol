// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds} from "../../src/errors/FleetCommanderErrors.sol";
import {CooldownNotElapsed} from "../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IArk} from "../../src/interfaces/IArk.sol";

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
            amount: 1000 * 10 ** 6
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
        mockArkTotalAssets(ark1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark2, ARK2_MAX_ALLOCATION); // Already at max allocation
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

    function test_RebalanceLowerRate() public {
        // Arrange
        mockArkTotalAssets(ark1, 5000 * 10 ** 6);
        mockArkTotalAssets(ark2, 5000 * 10 ** 6);
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
}
