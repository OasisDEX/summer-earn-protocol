// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import {RebalanceData} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderInvalidSourceArk, FleetCommanderNoExcessFunds} from "../../src/errors/FleetCommanderErrors.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

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
        vm.stopPrank();
    }

    function test_AdjustBufferSuccess() public {
        // Arrange
        uint256 initialBufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set initial buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        // Mock Ark behavior
        mockArkRate(ark1, 105);
        mockArkRate(ark2, 110);

        // Prepare rebalance data
        RebalanceData[] memory rebalanceData = new RebalanceData[](2);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 3000 * 10 ** 6
        });
        rebalanceData[1] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark2,
            amount: 2000 * 10 ** 6
        });

        // Act
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );
        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }

    function test_AdjustBufferNoExcessFunds() public {
        // Arrange
        uint256 bufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(bufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(bufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(FleetCommanderNoExcessFunds.selector)
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function test_AdjustBufferInvalidSourceArk() public {
        // Arrange
        uint256 bufferBalance = 15000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(bufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: ark1, // Invalid source, should be FleetCommander
            toArk: ark2,
            amount: 1000 * 10 ** 6
        });

        // Act & Assert
        vm.prank(keeper);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderInvalidSourceArk.selector,
                ark1
            )
        );
        fleetCommander.adjustBuffer(rebalanceData);
    }

    function test_AdjustBufferPartialMove() public {
        // Arrange
        uint256 initialBufferBalance = 12000 * 10 ** 6;
        uint256 minBufferBalance = 10000 * 10 ** 6;

        // Set buffer balance and min buffer balance
        fleetCommanderStorageWriter.setFundsBufferBalance(initialBufferBalance);
        fleetCommanderStorageWriter.setMinFundsBufferBalance(minBufferBalance);

        // Mock token balance
        mockToken.mint(address(fleetCommander), initialBufferBalance);

        mockArkRate(ark1, 105);

        RebalanceData[] memory rebalanceData = new RebalanceData[](1);
        rebalanceData[0] = RebalanceData({
            fromArk: address(fleetCommander),
            toArk: ark1,
            amount: 3000 * 10 ** 6 // More than excess funds
        });

        // Act
        vm.prank(keeper);
        fleetCommander.adjustBuffer(rebalanceData);

        // Assert
        assertEq(
            fleetCommander.fundsBufferBalance(),
            minBufferBalance,
            "Buffer balance should be equal to minBufferBalance"
        );

        assertEq(
            fleetCommander.totalAssets(),
            initialBufferBalance,
            "Total assets should remain unchanged"
        );
    }
}
