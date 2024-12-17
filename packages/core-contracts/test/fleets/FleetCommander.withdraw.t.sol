// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {IFleetCommanderEvents} from "../../src/events/IFleetCommanderEvents.sol";
import {TestHelpers} from "../helpers/TestHelpers.sol";

import {IArk} from "../../src/interfaces/IArk.sol";

import {FleetConfig} from "../../src/types/FleetCommanderTypes.sol";
import {FleetCommanderTestBase} from "./FleetCommanderTestBase.sol";
import {IERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

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
contract WithdrawTest is Test, TestHelpers, FleetCommanderTestBase {
    using PercentageUtils for uint256;

    uint256 constant DEPOSIT_AMOUNT = 1000 * 10 ** 6;
    uint256 initialConversionRate;

    function setUp() public {
        uint256 initialTipRate = 0;
        initializeFleetCommanderWithMockArks(initialTipRate);

        // Arrange (Deposit first)
        mockToken.mint(mockUser, DEPOSIT_AMOUNT);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        fleetCommander.deposit(DEPOSIT_AMOUNT, mockUser);
        vm.stopPrank();

        initialConversionRate = fleetCommander.convertToAssets(1000000);

        vm.prank(governor);
        fleetCommander.setMinimumBufferBalance(0);
    }

    function test_ConversionRateChange() public {
        mockToken.mint(ark1, 100000);
        uint256 newConversionRate = fleetCommander.convertToAssets(1000000);
        assertGt(
            newConversionRate,
            initialConversionRate,
            "Conversion rate should increase after interest accrual"
        );
    }

    function test_UserCanWithdrawAssets() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 10;
        uint256 depositShares = fleetCommander.balanceOf(mockUser);
        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            assetsToWithdraw,
            mockUser,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(mockUser),
            assetsToWithdraw,
            "Incorrect assets withdrawn"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - sharesRedeemed,
            "Incorrect remaining shares"
        );
    }

    function test_WithdrawMultipleTimes() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 3;
        uint256 depositShares = fleetCommander.balanceOf(mockUser);
        vm.startPrank(mockUser);
        uint256 shares1 = fleetCommander.withdraw(
            assetsToWithdraw,
            mockUser,
            mockUser
        );
        uint256 shares2 = fleetCommander.withdraw(
            assetsToWithdraw,
            mockUser,
            mockUser
        );
        uint256 shares3 = fleetCommander.withdraw(
            fleetCommander.maxWithdraw(mockUser),
            mockUser,
            mockUser
        );
        vm.stopPrank();

        assertEq(
            shares1 + shares2 + shares3,
            depositShares,
            "Should redeem all shares"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should have received all assets back"
        );
    }

    function test_WithdrawZero() public {
        uint256 depositShares = fleetCommander.balanceOf(mockUser);
        vm.prank(mockUser);
        vm.expectRevert(abi.encodeWithSignature("FleetCommanderZeroAmount()"));
        fleetCommander.withdraw(0, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares,
            "User shares should remain unchanged"
        );
    }

    function test_WithdrawExceedingBalance() public {
        uint256 excessAmount = DEPOSIT_AMOUNT + 1;

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                excessAmount,
                DEPOSIT_AMOUNT
            )
        );
        vm.prank(mockUser);
        fleetCommander.withdraw(excessAmount, mockUser, mockUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                excessAmount,
                DEPOSIT_AMOUNT
            )
        );
        vm.prank(mockUser);
        fleetCommander.withdrawFromBuffer(excessAmount, mockUser, mockUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                excessAmount,
                DEPOSIT_AMOUNT
            )
        );
        vm.prank(mockUser);
        fleetCommander.withdrawFromArks(excessAmount, mockUser, mockUser);
    }

    function test_WithdrawByNonOwner() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdraw(assetsToWithdraw, nonOwner, mockUser);
    }

    function test_WithdrawByNonOwnerWithSufficientAllowance() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;
        uint256 sharesToAllow = fleetCommander.previewWithdraw(
            assetsToWithdraw
        );

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, sharesToAllow);

        vm.prank(nonOwner);
        fleetCommander.withdraw(assetsToWithdraw, nonOwner, mockUser);
    }

    function test_WithdrawByNonOwnerWithInsufficientAllowance() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;
        uint256 sharesToAllow = fleetCommander.previewWithdraw(
            assetsToWithdraw
        ) - 1;

        vm.prank(mockUser);
        fleetCommander.approve(nonOwner, sharesToAllow);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdraw(assetsToWithdraw, nonOwner, mockUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdrawFromArks(assetsToWithdraw, nonOwner, mockUser);

        vm.expectRevert(
            abi.encodeWithSignature(
                "FleetCommanderUnauthorizedWithdrawal(address,address)",
                nonOwner,
                mockUser
            )
        );

        vm.prank(nonOwner);
        fleetCommander.withdrawFromBuffer(assetsToWithdraw, nonOwner, mockUser);
    }

    function test_WithdrawToOtherReceiver() public {
        address receiver = nonOwner;
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        fleetCommander.withdraw(assetsToWithdraw, receiver, mockUser);

        assertEq(
            mockToken.balanceOf(receiver),
            assetsToWithdraw,
            "Receiver should have received the assets"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            0,
            "Owner should not have received any assets"
        );
    }

    function test_WithdrawEventEmission() public {
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;
        uint256 expectedShares = fleetCommander.previewWithdraw(
            assetsToWithdraw
        );

        vm.expectEmit(true, true, true, true);
        emit IERC4626.Withdraw(
            mockUser,
            mockUser,
            mockUser,
            assetsToWithdraw,
            expectedShares
        );

        vm.prank(mockUser);
        fleetCommander.withdraw(assetsToWithdraw, mockUser, mockUser);
    }

    function test_WithdrawUpdatesBufferBalance() public {
        FleetConfig memory config = fleetCommander.getConfig();
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;
        uint256 initialBufferBalance = config.bufferArk.totalAssets();

        vm.prank(mockUser);
        fleetCommander.withdraw(assetsToWithdraw, mockUser, mockUser);

        uint256 finalBufferBalance = config.bufferArk.totalAssets();
        assertEq(
            finalBufferBalance,
            initialBufferBalance - assetsToWithdraw,
            "Buffer balance should decrease by withdrawn assets"
        );
    }

    function test_WithdrawWithRebalancedFunds() public {
        // Move some funds to different arks
        FleetConfig memory config = fleetCommander.getConfig();
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        vm.startPrank(keeper);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark1,
                DEPOSIT_AMOUNT / 3
            )
        );
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark2,
                DEPOSIT_AMOUNT / 3
            )
        );
        vm.stopPrank();

        vm.prank(mockUser);
        fleetCommander.withdraw(DEPOSIT_AMOUNT, mockUser, mockUser);

        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should have received all assets back"
        );
    }

    function test_WithdrawExactlyBufferLimit() public {
        uint256 depositShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);
        uint256 maxBufferWithdraw = fleetCommander.maxBufferWithdraw(mockUser);

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            maxBufferWithdraw,
            mockUser,
            mockUser
        );

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
        // Move some funds to arks
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

    function test_WithdrawAll() public {
        uint256 depositShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);
        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            type(uint256).max,
            mockUser,
            mockUser
        );

        assertEq(sharesRedeemed, depositShares, "Should redeem all shares");
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should receive all assets"
        );
    }

    function test_WithdrawFromBuffer() public {
        uint256 depositShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            assetsToWithdraw,
            mockUser,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(mockUser),
            assetsToWithdraw,
            "User should receive withdrawn assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - sharesRedeemed,
            "User should have remaining shares"
        );
    }

    function test_WithdrawFromBufferDirectly() public {
        uint256 depositShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);
        uint256 assetsToWithdraw = DEPOSIT_AMOUNT / 2;

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdrawFromBuffer(
            assetsToWithdraw,
            mockUser,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(mockUser),
            assetsToWithdraw,
            "User should receive withdrawn assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - sharesRedeemed,
            "User should have remaining shares"
        );
    }

    function test_WithdrawFromArks() public {
        // Move some funds to arks
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

        uint256 depositShares = fleetCommander.convertToShares(DEPOSIT_AMOUNT);
        uint256 assetsToWithdraw = (DEPOSIT_AMOUNT * 3) / 4;

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            assetsToWithdraw,
            mockUser,
            mockUser
        );

        assertEq(
            mockToken.balanceOf(mockUser),
            assetsToWithdraw,
            "User should receive withdrawn assets"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            depositShares - sharesRedeemed,
            "User should have remaining shares"
        );
    }

    function test_MaxBufferWithdraw() public {
        FleetConfig memory config = fleetCommander.getConfig();
        uint256 maxBufferWithdraw = fleetCommander.maxBufferWithdraw(mockUser);
        assertEq(
            maxBufferWithdraw,
            DEPOSIT_AMOUNT,
            "Max buffer withdraw should equal deposit amount"
        );

        // Move some funds to arks
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

        maxBufferWithdraw = fleetCommander.maxBufferWithdraw(mockUser);
        assertEq(
            maxBufferWithdraw,
            DEPOSIT_AMOUNT / 2,
            "Max buffer withdraw should equal remaining buffer amount"
        );
    }

    function test_WithdrawForce_withNonWithdrawableArk() public {
        FleetConfig memory config = fleetCommander.getConfig();

        // Move some funds to arks
        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark1,
                DEPOSIT_AMOUNT / 4
            )
        );
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark2,
                DEPOSIT_AMOUNT / 4
            )
        );
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark4,
                DEPOSIT_AMOUNT / 4,
                bytes("dummy data 12345 dummy data 1234"), // mock ark validates lenngth of call data to be 32 bytes
                bytes("")
            )
        );
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSignature(
                "ERC4626ExceededMaxWithdraw(address,uint256,uint256)",
                mockUser,
                DEPOSIT_AMOUNT,
                fleetCommander.maxWithdraw(mockUser)
            )
        );
        vm.prank(mockUser);
        fleetCommander.withdrawFromArks(DEPOSIT_AMOUNT, mockUser, mockUser);
    }

    function test_WithdrawForce() public {
        FleetConfig memory config = fleetCommander.getConfig();
        uint256 depositShares = fleetCommander.balanceOf(mockUser);
        // Move some funds to arks
        vm.startPrank(keeper);
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark1,
                DEPOSIT_AMOUNT / 2
            )
        );
        vm.warp(block.timestamp + INITIAL_REBALANCE_COOLDOWN);
        fleetCommander.rebalance(
            generateRebalanceData(
                address(config.bufferArk),
                ark2,
                DEPOSIT_AMOUNT / 4
            )
        );
        vm.stopPrank();

        vm.prank(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdrawFromArks(
            DEPOSIT_AMOUNT,
            mockUser,
            mockUser
        );

        assertEq(
            sharesRedeemed,
            depositShares,
            "Should force withdraw full amount of shares"
        );
        assertEq(
            fleetCommander.balanceOf(mockUser),
            0,
            "User should have no remaining shares"
        );
        assertEq(
            mockToken.balanceOf(mockUser),
            DEPOSIT_AMOUNT,
            "User should receive all assets"
        );
    }

    function test_Withdraw_withTip() public {
        // Initial setup and deposit
        fleetCommanderStorageWriter.setTipRate(1e18);
        mockToken.mint(mockUser, DEPOSIT_AMOUNT * 2);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        uint256 sharesBefore = fleetCommander.balanceOf(mockUser);
        uint256 receivedShares = fleetCommander.deposit(
            DEPOSIT_AMOUNT,
            mockUser
        );
        uint256 sharesAfter = fleetCommander.balanceOf(mockUser);

        // Advance time to accrue tip
        vm.warp(block.timestamp + 10 days);

        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 previewedShares = fleetCommander.previewWithdraw(
            withdrawAmount
        );
        uint256 balanceBefore = mockToken.balanceOf(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdraw(
            withdrawAmount,
            mockUser,
            mockUser
        );
        uint256 balanceAfter = mockToken.balanceOf(mockUser);
        uint256 sharesAfterRedemption = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();

        assertEq(
            sharesRedeemed,
            previewedShares,
            "Redeemed shares should match preview"
        );
        assertEq(
            balanceAfter,
            balanceBefore + withdrawAmount,
            "Should receive correct withdrawal amount"
        );
        assertEq(
            sharesAfter,
            sharesBefore + receivedShares,
            "User should have remaining shares"
        );
        assertEq(
            sharesAfterRedemption,
            sharesAfter - sharesRedeemed,
            "User should have remaining shares after redemption"
        );
    }

    function test_WithdrawFromBuffer_withTip() public {
        // Initial setup and deposit
        fleetCommanderStorageWriter.setTipRate(1e18);
        mockToken.mint(mockUser, DEPOSIT_AMOUNT * 2);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        uint256 sharesBefore = fleetCommander.balanceOf(mockUser);
        uint256 receivedShares = fleetCommander.deposit(
            DEPOSIT_AMOUNT,
            mockUser
        );
        uint256 sharesAfter = fleetCommander.balanceOf(mockUser);

        // Advance time to accrue tip
        vm.warp(block.timestamp + 10 days);

        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 previewedShares = fleetCommander.previewWithdraw(
            withdrawAmount
        );
        uint256 balanceBefore = mockToken.balanceOf(mockUser);
        uint256 sharesRedeemed = fleetCommander.withdrawFromBuffer(
            withdrawAmount,
            mockUser,
            mockUser
        );
        uint256 balanceAfter = mockToken.balanceOf(mockUser);
        uint256 sharesAfterRedemption = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();

        assertEq(
            sharesRedeemed,
            previewedShares,
            "Redeemed shares should match preview"
        );
        assertEq(
            balanceAfter,
            balanceBefore + withdrawAmount,
            "Should receive correct withdrawal amount"
        );
        assertEq(
            sharesAfter,
            sharesBefore + receivedShares,
            "User should have remaining shares"
        );
        assertEq(
            sharesAfterRedemption,
            sharesAfter - sharesRedeemed,
            "User should have remaining shares after redemption"
        );
    }

    function test_WithdrawFromArks_withTip() public {
        // Initial setup and deposit
        fleetCommanderStorageWriter.setTipRate(1e18);
        mockToken.mint(mockUser, DEPOSIT_AMOUNT * 2);

        vm.startPrank(mockUser);
        mockToken.approve(address(fleetCommander), DEPOSIT_AMOUNT);
        uint256 sharesBefore = fleetCommander.balanceOf(mockUser);
        uint256 receivedShares = fleetCommander.deposit(
            DEPOSIT_AMOUNT,
            mockUser
        );
        uint256 sharesAfter = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();

        // Move funds to arks
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
        // Advance time to accrue tip
        vm.warp(block.timestamp + 10 days);
        vm.startPrank(mockUser);
        uint256 withdrawAmount = DEPOSIT_AMOUNT / 2;
        uint256 previewedShares = fleetCommander.previewWithdraw(
            withdrawAmount
        );

        uint256 balanceBefore = mockToken.balanceOf(mockUser);

        uint256 sharesRedeemed = fleetCommander.withdrawFromArks(
            withdrawAmount,
            mockUser,
            mockUser
        );
        uint256 balanceAfter = mockToken.balanceOf(mockUser);
        uint256 sharesAfterRedemption = fleetCommander.balanceOf(mockUser);
        vm.stopPrank();

        assertEq(
            sharesRedeemed,
            previewedShares,
            "Redeemed shares should match preview"
        );
        assertEq(
            balanceAfter,
            balanceBefore + withdrawAmount,
            "Should receive correct withdrawal amount"
        );
        assertEq(
            sharesAfter,
            sharesBefore + receivedShares,
            "User should have remaining shares"
        );
        assertEq(
            sharesAfterRedemption,
            sharesAfter - sharesRedeemed,
            "User should have remaining shares after redemption"
        );
    }
}
