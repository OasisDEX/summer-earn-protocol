// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds, FleetCommanderInvalidBufferAdjustment, FleetCommanderInsufficientBuffer, FleetCommanderInsufficientBuffer} from "../../src/errors/FleetCommanderErrors.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IArk} from "../../src/interfaces/IArk.sol";

/**
 * @title Buffer test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's fund buffer functionality

 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Buffer adjustment
 * - Error cases and edge scenarios
 */
contract BufferTest is Test, ArkTestHelpers, FleetCommanderTestBase {
    function setUp() public {
        // Each fleet uses a default setup from the FleetCommanderTestBase contract,
        // but you can create and initialize your own custom fleet if you wish.
        fleetCommander = new FleetCommander(fleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        mockArk1.grantCommanderRole(address(fleetCommander));
        mockArk2.grantCommanderRole(address(fleetCommander));
        mockArk3.grantCommanderRole(address(fleetCommander));
        bufferArk.grantCommanderRole(address(fleetCommander));
        vm.stopPrank();
    }

    function test_AdjustBufferSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;
        uint256 ark2RebalanceAmount = 2000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        // Mock Ark behavior
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: ark1RebalanceAmount
        });
        rebalanceData[1] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark2,
            amount: ark2RebalanceAmount
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
        assertEq(
            mockArk1.totalAssets(),
            ark1RebalanceAmount,
            "Ark1 should have ark1RebalanceAmount assets"
        );
        assertEq(
            mockArk2.totalAssets(),
            ark2RebalanceAmount,
            "Ark2 should have ark2RebalanceAmount assets"
        );
        // Prepare rebalance data
        RebalanceData[] memory rebalanceFromData = new RebalanceData[](2);
        rebalanceFromData[0] = RebalanceData({
            fromArk: ark1,
            toArk: bufferArkAddress,
            amount: ark1RebalanceAmount
        });
        rebalanceFromData[1] = RebalanceData({
            fromArk: ark2,
            toArk: bufferArkAddress,
            amount: ark2RebalanceAmount
        });

        // Act round 2
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert round 2
        assertEq(
            IArk(fleetCommander.bufferArk()).totalAssets(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
        assertEq(mockArk1.totalAssets(), 0, "Ark1 should have no assets");
        assertEq(mockArk2.totalAssets(), 0, "Ark2 should have no assets");
    }

    function test_AdjustBufferMovingMoreThanAllowed() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        // Mock Ark behavior
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: ark1RebalanceAmount
        });
        rebalanceData[1] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark2,
            amount: ark1RebalanceAmount
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderInsufficientBuffer.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
        vm.stopPrank();
    }

    function test_AdjustBufferNoExcessFunds() public {
        // Arrange
        uint256 bufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(bufferArkAddress),
            toArk: ark1,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderNoExcessFunds.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
        vm.stopPrank();
    }

    function test_AdjustBufferInvalidSourceArk() public {
        // Arrange
        uint256 bufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        mockToken.mint(address(bufferArkAddress), bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1, // Invalid source, should be FleetCommander
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderInvalidBufferAdjustment.selector
            )
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function test_AdjustBufferPartialMove() public {
        // Arrange
        uint256 initialBufferBalance = 12000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;
        uint256 ark1RebalanceAmount = 3000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(bufferArkAddress), initialBufferBalance);

        mockArkRate(ark1, 105);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: bufferArkAddress,
            toArk: ark1,
            amount: ark1RebalanceAmount // More than excess funds
        });

        // Act
        vm.warp(INITIAL_REBALANCE_COOLDOWN);
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderInsufficientBuffer.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }
}
