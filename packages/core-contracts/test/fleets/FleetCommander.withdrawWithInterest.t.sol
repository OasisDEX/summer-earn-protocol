// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IArk} from "../../src/interfaces/IArk.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";

import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract WithdrawWithInterestTest is Test, TestHelpers, FleetCommanderTestBase {
    using PercentageUtils for uint256;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 constant INTEREST_AMOUNT = 100 * 10 ** 6; // 10% interest
    uint256 depositShares;
    uint256 initialConversionRate;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);

        // Deposit for tests
        mockToken.mint(mockUser, DEPOSIT_AMOUNT);
        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        depositShares = fleetCommander.deposit(DEPOSIT_AMOUNT, mockUser);
        vm.stopPrank();

        initialConversionRate = fleetCommander.convertToAssets(100000);

        // Simulate interest accrual
        FleetConfig memory config = fleetCommander.getConfig();
        mockToken.mint(address(config.bufferArk), INTEREST_AMOUNT);

        vm.prank(governor);
        fleetCommander.setMinimumBufferBalance(0);
    }

    function test_ConversionRateChange() public view {
        uint256 newConversionRate = fleetCommander.convertToAssets(100000);
        assertGt(
            newConversionRate,
            initialConversionRate,
            "Conversion rate should increase after interest accrual"
        );
    }

    function test_WithdrawExactlyBufferLimit() public {
        uint256 maxBufferWithdraw = fleetCommander.maxBufferWithdraw(mockUser);
        console.log("maxBufferWithdraw", maxBufferWithdraw);
        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            maxBufferWithdraw,
            mockUser,
            mockUser
        );
        console.log("sharesRedeemed", sharesRedeemed);
        console.log("depositShares", depositShares);
        assertEq(
            mockToken.balanceOf(mockUser),
            maxBufferWithdraw,
            "User should receive exact buffer limit"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - sharesRedeemed,
            "User should have remaining shares"
        );
    }

    function test_WithdrawBufferPlusOne() public {
        FleetConfig memory config = fleetCommander.getConfig();
        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark1,
                DEPOSIT_AMOUNT / 2
            )
        );
        vm.stopPrank();

        uint256 maxBufferWithdraw = fleetCommander.maxBufferWithdraw(mockUser);
        uint256 withdrawAmount = maxBufferWithdraw + 1;

        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderEvents.FleetCommanderWithdrawnFromArks(
            mockUser,
            mockUser,
            withdrawAmount
        );
        vm.prank(mockUser);
        fleetCommander.withdraw(withdrawAmount, mockUser, mockUser);
    }

    function test_WithdrawAllAssets() public {
        uint256 totalUserAssets = fleetCommander.maxWithdraw(mockUser);

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            totalUserAssets,
            mockUser,
            mockUser
        );

        assertEq(
            sharesRedeemed,
            depositShares,
            "All shares should be redeemed"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            totalUserAssets,
            "User should receive all assets including interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
    }

    function test_WithdrawPartialWithInterest() public {
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            withdrawAmount,
            mockUser,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(mockUser),
            withdrawAmount,
            "User should receive requested assets"
        );
        assertLt(
            sharesRedeemed,
            depositShares / 2,
            "Less shares should be redeemed due to interest"
        );
        assertGt(
            fleetCommander.balanceOf(mockUser),
            depositShares / 2,
            "User should have more than half shares remaining"
        );
    }

    function test_MaxWithdrawIncreasedWithInterest() public view {
        uint256 maxWithdraw = fleetCommander.maxWithdraw(mockUser);
        assertGt(
            maxWithdraw,
            DEPOSIT_AMOUNT,
            "Max withdraw should be greater than initial deposit due to interest"
        );
    }

    function test_WithdrawAllWithWithdrawFromArks() public {
        uint256 totalUserAssets = fleetCommander.maxWithdraw(mockUser);

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdrawFromArks(
            totalUserAssets,
            mockUser,
            mockUser
        );

        assertEq(
            sharesRedeemed,
            depositShares,
            "All shares should be redeemed"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            totalUserAssets,
            "User should receive all assets including interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
    }

    function test_WithdrawToOtherReceiverWithInterest() public {
        address receiver = address(0x123);
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            withdrawAmount,
            receiver,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(receiver),
            withdrawAmount,
            "Receiver should get requested assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "User should not receive any assets"
        );
        assertLt(
            sharesRedeemed,
            depositShares / 2,
            "Less shares should be redeemed due to interest"
        );
    }

    function test_WithdrawAfterMultipleInterestAccruals() public {
        // Simulate multiple interest accruals
        for (uint256 i = 0; i < 3; i++) {
            mockToken.mint(ark2, INTEREST_AMOUNT / 3);
        }

        uint256 userShares = fleetCommander.balanceOf(mockUser);
        uint256 userAssets = fleetCommander.previewRedeem(userShares);

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            userAssets,
            mockUser,
            mockUser
        );

        assertEq(
            sharesRedeemed,
            userShares,
            "All user shares should be redeemed"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            userAssets,
            "User should receive all assets including all interest"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
    }

    function test_TwoUsersWithdrawAllAssets() public {
        FleetConfig memory config = fleetCommander.getConfig();

        // Setup second user
        address secondUser = address(0x456);
        mockToken.mint(secondUser, DEPOSIT_AMOUNT);
        vm.startPrank(secondUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        fleetCommander.deposit(DEPOSIT_AMOUNT, secondUser);
        vm.stopPrank();

        // Simulate more interest accrual
        mockToken.mint(address(config.bufferArk), INTEREST_AMOUNT);

        uint256 totalAssets = fleetCommander.totalAssets();
        uint256 totalShares = fleetCommander.totalSupply();
        uint256 user1MaxWithdraw = fleetCommander.maxWithdraw(mockUser);
        uint256 user2MaxWithdraw = fleetCommander.maxWithdraw(secondUser);

        // First user withdraws
        vm.prank(mockUser);
        uint256 user1SharesRedeemed = fleetCommander.withdraw(
            user1MaxWithdraw,
            mockUser,
            mockUser
        );

        // Second user withdraws
        vm.prank(secondUser);
        uint256 user2SharesRedeemed = fleetCommander.withdraw(
            user2MaxWithdraw,
            secondUser,
            secondUser
        );

        // Verify results
        assertEq(
            totalShares,
            user1SharesRedeemed + user2SharesRedeemed,
            "All shares should be redeemed"
        );
        assertEq(
            fleetCommander.totalAssets() - 1,
            0,
            "FleetCommander should be empty"
        );
        assertEq(fleetCommander.totalSupply(), 0, "No shares should remain");
        assertEq(
            mockToken.balanceOf(mockUser) + mockToken.balanceOf(secondUser),
            totalAssets - 1,
            "Users should have withdrawn all assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "First user should have no shares"
        );
        assertEq(
            fleetCommander.balanceOf(secondUser),
            0,
            "Second user should have no shares"
        );
    }
}
