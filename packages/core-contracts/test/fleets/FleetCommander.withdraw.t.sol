// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ArkTestHelpers} from "../helpers/ArkHelpers.sol";
import "../../src/errors/FleetCommanderErrors.sol";

import {FleetCommanderStorageWriter} from "../helpers/FleetCommanderStorageWriter.sol";
import {FleetCommanderTestBase} from "./FleetCommanderHelpers.sol";

/**
 * @title Withdraw test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's withdraw functionality
 *
 * @dev TODO : add more tests
 *
 * Test coverage:
 * - Withdraw
 * - Error cases and edge scenarios
 */
contract Withdraw is Test, ArkTestHelpers, FleetCommanderTestBase {
    uint256 depositAmount = 1000 * 10 ** 6;

    function setUp() public {
        fleetCommander = new FleetCommander(defaultFleetCommanderParams);
        fleetCommanderStorageWriter = new FleetCommanderStorageWriter(
            address(fleetCommander)
        );

        vm.startPrank(governor);
        accessManager.grantKeeperRole(keeper);
        mockArk1.grantCommanderRole(address(fleetCommander));
        mockArk2.grantCommanderRole(address(fleetCommander));
        mockArk3.grantCommanderRole(address(fleetCommander));
        vm.stopPrank();

        // Arrange (Deposit first)
        mockToken.mint(mockUser, depositAmount);

        vm.prank(mockUser);
        mockToken.approve(address(fleetCommander), depositAmount);
        // since the funds do not leave the queue in this test we do not need to mock the total assets
        mockArkTotalAssets(ark1, 0);
        mockArkTotalAssets(ark2, 0);

        vm.prank(mockUser);
        fleetCommander.deposit(depositAmount, mockUser);
    }

    function test_UserCanWithdrawTokens() public {
        // Arrange - confirm user has deposited
        assertEq(depositAmount, fleetCommander.balanceOf(mockUser));

        // Act
        vm.prank(mockUser);
        uint256 withdrawalAmount = depositAmount / 10;
        fleetCommander.withdraw(depositAmount / 10, mockUser, mockUser);

        // Assert
        assertEq(
            depositAmount - withdrawalAmount,
            fleetCommander.balanceOf(mockUser)
        );
    }

    function test_RevertIfArkDepositCapNotZero() public {
        // Act & Assert
        vm.prank(governor);
        mockArkDepositCap(ark1, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkDepositCapGreaterThanZero.selector,
                ark1
            )
        );
        fleetCommander.removeArk(ark1);
    }

    function test_RevertIfArkTotalAssetsNotZero() public {
        // Act & Assert
        vm.prank(governor);
        mockArkTotalAssets(ark1, 100);
        vm.expectRevert(
            abi.encodeWithSelector(
                FleetCommanderArkAssetsNotZero.selector,
                ark1
            )
        );
        fleetCommander.removeArk(ark1);
    }
}
