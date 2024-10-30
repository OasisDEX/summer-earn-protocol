// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IArk} from "../../src/interfaces/IArk.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

/**
 * @title ERC4626 methods test suite for FleetCommander
 * @dev Test suite for the FleetCommander contract's ERC4626 methods
 */
contract ERC4626Test is Test, TestHelpers, FleetCommanderTestBase {
    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);
    }

    function test_MaxDeposit() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 depositCap = 100000 * 10 ** 6;

        // Set deposit cap and total assets
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.prank(mockUser);
        uint256 maxDeposit = fleetCommander.maxDeposit(mockUser);

        // Assert
        assertEq(
            maxDeposit,
            userBalance,
            "Max deposit should be the user balance - first deposit so shares equal balance"
        );
    }

    function test_MaxMint() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 depositCap = 50000 * 10 ** 6;

        // Set deposit cap and total assets
        fleetCommanderStorageWriter.setDepositCap(depositCap);

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.prank(mockUser);
        uint256 maxMint = fleetCommander.maxMint(mockUser);

        // Assert
        assertEq(
            maxMint,
            userBalance,
            "Max mint should be the user balance - first deposit so shares equal balance"
        );
    }

    function test_MaxWithdraw() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 bufferBalance = bufferArk.totalAssets();

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), userBalance);
        fleetCommander.deposit(userBalance, mockUser);
        uint256 maxWithdraw = fleetCommander.maxWithdraw(mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            maxWithdraw,
            (bufferBalance + userBalance),
            "Max withdraw should be the the total assets (initial buffer + deposited user funds)"
        );
    }

    function test_MaxRedeem() public {
        // Arrange
        uint256 userBalance = 1000 * 10 ** 6;
        uint256 bufferBalance = bufferArk.totalAssets();

        // Mock user balance
        mockToken.mint(mockUser, userBalance);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), userBalance);
        fleetCommander.deposit(userBalance, mockUser);
        uint256 maxRedeem = fleetCommander.maxRedeem(mockUser);

        // Assert
        assertEq(
            maxRedeem,
            (bufferBalance + userBalance),
            "Max redeem should be the total assets (initial buffer + deposited user funds)"
        );
    }

    function test_Mint() public {
        // Arrange
        uint256 mintAmount = 1000 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;
        uint256 bufferBalance = bufferArk.totalAssets();

        // Set buffer balance
        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);

        mockToken.mint(mockUser, mintAmount);

        // Act
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), mintAmount);
        fleetCommander.mint(mintAmount, mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            fleetCommander.balanceOf(mockUser),
            mintAmount,
            "Mint should increase the user's balance"
        );
        assertEq(
            bufferArk.totalAssets(),
            bufferBalance + mintAmount,
            "Buffer balance should be updated"
        );
    }

    function test_Redeem() public {
        // Arrange
        uint256 depositAmount = 1000 * 10 ** 6;
        uint256 redeemAmount = 100 * 10 ** 6;
        uint256 maxDepositCap = 100000 * 10 ** 6;

        // Set buffer balance
        fleetCommanderStorageWriter.setDepositCap(maxDepositCap);

        mockToken.mint(mockUser, depositAmount);

        // Deposit first
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), depositAmount);
        fleetCommander.deposit(depositAmount, mockUser);

        uint256 bufferBalance = bufferArk.totalAssets();

        // Act
        fleetCommander.redeem(redeemAmount, mockUser, mockUser);
        vm.stopPrank();

        // Assert
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositAmount - redeemAmount,
            "Redeem should decrease the user's balance"
        );
        assertEq(
            bufferArk.totalAssets(),
            bufferBalance - redeemAmount,
            "Buffer balance should be updated"
        );
    }
}
