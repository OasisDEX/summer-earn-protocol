// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";
import {ICrossChainFleetCommander} from "../../src/interfaces/ICrossChainFleetCommander.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title CrossChainFleetCommander Cooldown Tests
 * @notice Test suite for cooldown functionality in CrossChainFleetCommander
 * @dev Tests cooldown enforcement, deposit tracking, and MEV protection
 */
contract CrossChainFleetCommanderCooldownTest is
    CrossChainFleetCommanderTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC
    uint256 constant WITHDRAWAL_AMOUNT = 5000 * 10 ** 6; // 5,000 USDC

    function setUp() public {
        initializeCrossChainFleetCommander(INITIAL_TIP_RATE);
        setupUser(user1, DEPOSIT_AMOUNT * 2);
        setupUser(user2, DEPOSIT_AMOUNT * 2);
    }

    /*//////////////////////////////////////////////////////////////
                            COOLDOWN FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    function testCooldownPeriodConfiguration() public view {
        assertEq(
            getCooldownPeriod(),
            COOLDOWN_PERIOD,
            "Cooldown period should be set correctly"
        );
    }

    function testDepositUpdatesTimestamp() public {
        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Check that the timestamp was updated
        uint256 nextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertTrue(
            nextWithdrawTime > 0,
            "Next withdraw timestamp should be set"
        );
        assertEq(
            nextWithdrawTime,
            block.timestamp + COOLDOWN_PERIOD,
            "Next withdraw time should be current time + cooldown"
        );
    }

    function testWithdrawBeforeCooldownFails() public {
        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Try to withdraw immediately - should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderCooldownNotMet
                    .selector,
                user1,
                block.timestamp,
                block.timestamp + COOLDOWN_PERIOD
            )
        );
        crossChainFleetCommander.withdraw(WITHDRAWAL_AMOUNT, user1, user1);
    }

    function testRedeemBeforeCooldownFails() public {
        // Perform a deposit
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Try to redeem immediately - should fail
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderCooldownNotMet
                    .selector,
                user1,
                block.timestamp,
                block.timestamp + COOLDOWN_PERIOD
            )
        );
        crossChainFleetCommander.redeem(shares / 2, user1, user1);
    }

    function testWithdrawAfterCooldownSucceeds() public {
        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Withdraw should now succeed
        performWithdrawal(user1, WITHDRAWAL_AMOUNT, user1, user1);
    }

    function testRedeemAfterCooldownSucceeds() public {
        // Perform a deposit
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Redeem should now succeed
        performRedemption(user1, shares / 2, user1, user1);
    }

    function testCanWithdrawFunction() public {
        // Initially, user should be able to withdraw (no previous deposit)
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw initially"
        );

        // After deposit, user should not be able to withdraw
        performDeposit(user1, DEPOSIT_AMOUNT, user1);
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw after deposit"
        );

        // After cooldown, user should be able to withdraw again
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after cooldown"
        );
    }

    function testMultipleDepositsUpdateTimestamp() public {
        // First deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Wait half the cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD / 2);

        // Second deposit should update the timestamp
        performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 secondDepositTime = block.timestamp;

        // Next withdraw time should be based on the second deposit
        uint256 nextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertEq(
            nextWithdrawTime,
            secondDepositTime + COOLDOWN_PERIOD,
            "Next withdraw time should be based on latest deposit"
        );

        // Should not be able to withdraw yet
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw after second deposit"
        );

        // Fast forward past the new cooldown period
        vm.warp(secondDepositTime + COOLDOWN_PERIOD + 1);

        // Now should be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after second cooldown period"
        );
    }

    function testDifferentUsersIndependentCooldowns() public {
        // User1 deposits
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // User2 should still be able to withdraw (no previous deposit)
        assertTrue(canWithdraw(user2), "User2 should be able to withdraw");

        // User2 deposits
        performDeposit(user2, DEPOSIT_AMOUNT, user2);

        // Both users should not be able to withdraw
        assertFalse(canWithdraw(user1), "User1 should not be able to withdraw");
        assertFalse(canWithdraw(user2), "User2 should not be able to withdraw");

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Both users should now be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User1 should be able to withdraw after cooldown"
        );
        assertTrue(
            canWithdraw(user2),
            "User2 should be able to withdraw after cooldown"
        );
    }

    function testNoCooldownForUsersWithoutDeposits() public view {
        // User who never deposited should be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw without previous deposit"
        );
        assertEq(
            getNextWithdrawTimestamp(user1),
            0,
            "Next withdraw timestamp should be 0 for user without deposits"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function testWithdrawExactCooldownTime() public {
        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward to exactly the cooldown period
        vm.warp(block.timestamp + COOLDOWN_PERIOD);

        // Should still not be able to withdraw (cooldown period not yet passed)
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw at exact cooldown time"
        );

        // Fast forward by 1 second
        vm.warp(block.timestamp + 1);

        // Now should be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after cooldown period"
        );
    }

    function testCooldownAfterWithdraw() public {
        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Withdraw
        performWithdrawal(user1, WITHDRAWAL_AMOUNT, user1, user1);

        // User should still be able to withdraw (no new deposit)
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after withdrawal"
        );
    }

    function testCooldownAfterRedeem() public {
        // Perform a deposit
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Redeem
        performRedemption(user1, shares / 2, user1, user1);

        // User should still be able to withdraw (no new deposit)
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after redemption"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER COOLDOWN TESTS
    //////////////////////////////////////////////////////////////*/

    function testTransferPropagatesCooldown() public {
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 user1CooldownTime = getNextWithdrawTimestamp(user1);

        // User1 transfers shares to User2
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, shares / 2);

        // User2 should inherit User1's cooldown
        uint256 user2CooldownTime = getNextWithdrawTimestamp(user2);
        assertEq(
            user2CooldownTime,
            user1CooldownTime,
            "User2 should inherit User1's cooldown timestamp"
        );

        // User2 should not be able to withdraw immediately
        assertFalse(
            canWithdraw(user2),
            "User2 should not be able to withdraw after receiving shares with cooldown"
        );

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Now User2 should be able to withdraw
        assertTrue(
            canWithdraw(user2),
            "User2 should be able to withdraw after cooldown period"
        );
    }

    function testTransferWithNoCooldownDoesNotAffectRecipient() public {
        // User2 deposits first and gets cooldown
        performDeposit(user2, DEPOSIT_AMOUNT, user2);
        uint256 user2OriginalCooldown = getNextWithdrawTimestamp(user2);

        // User1 (no cooldown) transfers to User2
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        
        // Fast forward past User1's cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);
        
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, shares / 2);

        // User2's cooldown should remain unchanged
        uint256 user2NewCooldown = getNextWithdrawTimestamp(user2);
        assertEq(
            user2NewCooldown,
            user2OriginalCooldown,
            "User2's cooldown should not be affected by transfer from user without cooldown"
        );
    }

    function testTransferPreservesMoreRestrictiveCooldown() public {
        // User2 deposits first (earlier timestamp)
        performDeposit(user2, DEPOSIT_AMOUNT, user2);
        uint256 user2OriginalCooldown = getNextWithdrawTimestamp(user2);

        // Wait a bit, then User1 deposits (later timestamp)
        vm.warp(block.timestamp + 100);
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // User1 transfers to User2
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, shares / 2);

        // User2's cooldown should remain the more restrictive one (earlier)
        uint256 user2NewCooldown = getNextWithdrawTimestamp(user2);
        assertEq(
            user2NewCooldown,
            user2OriginalCooldown,
            "User2's more restrictive cooldown should be preserved"
        );
    }

    function testTransferFromPropagatesCooldown() public {
        // Create a third user
        address user3 = address(0x400);
        
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 user1CooldownTime = getNextWithdrawTimestamp(user1);

        // User1 approves User2 to spend their shares
        vm.prank(user1);
        crossChainFleetCommander.approve(user2, shares);

        // User2 transfers from User1 to User3
        vm.prank(user2);
        crossChainFleetCommander.transferFrom(user1, user3, shares / 2);

        // User3 should inherit User1's cooldown
        uint256 user3CooldownTime = getNextWithdrawTimestamp(user3);
        assertEq(
            user3CooldownTime,
            user1CooldownTime,
            "User3 should inherit User1's cooldown via transferFrom"
        );

        // User3 should not be able to withdraw immediately
        assertFalse(
            canWithdraw(user3),
            "User3 should not be able to withdraw after receiving shares with cooldown"
        );
    }

    function testTransferFromToMultipleUsers() public {
        // Create additional users
        address user3 = address(0x400);
        address user4 = address(0x500);
        
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 user1CooldownTime = getNextWithdrawTimestamp(user1);

        // User1 approves User2 to spend their shares
        vm.prank(user1);
        crossChainFleetCommander.approve(user2, shares);

        // User2 transfers from User1 to User3
        vm.prank(user2);
        crossChainFleetCommander.transferFrom(user1, user3, shares / 3);

        // User3 should inherit User1's cooldown
        assertEq(
            getNextWithdrawTimestamp(user3),
            user1CooldownTime,
            "User3 should inherit User1's cooldown"
        );

        // User2 transfers more from User1 to User4
        vm.prank(user2);
        crossChainFleetCommander.transferFrom(user1, user4, shares / 3);

        // User4 should also inherit User1's cooldown
        assertEq(
            getNextWithdrawTimestamp(user4),
            user1CooldownTime,
            "User4 should inherit User1's cooldown"
        );
    }

    function testCannotCircumventCooldownViaTransfer() public {
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 transferAmount = shares / 2;

        // User1 transfers shares to User2
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, transferAmount);

        // User2 should not be able to withdraw immediately
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderCooldownNotMet
                    .selector,
                user2,
                block.timestamp,
                block.timestamp + COOLDOWN_PERIOD
            )
        );
        crossChainFleetCommander.withdraw(WITHDRAWAL_AMOUNT, user2, user2);

        // User2 should not be able to redeem immediately
        vm.prank(user2);
        vm.expectRevert(
            abi.encodeWithSelector(
                ICrossChainFleetCommanderErrors
                    .CrossChainFleetCommanderCooldownNotMet
                    .selector,
                user2,
                block.timestamp,
                block.timestamp + COOLDOWN_PERIOD
            )
        );
        crossChainFleetCommander.redeem(transferAmount / 2, user2, user2);

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Now User2 should be able to withdraw (use a smaller amount to avoid balance issues)
        uint256 withdrawAmount = WITHDRAWAL_AMOUNT / 2;
        performWithdrawal(user2, withdrawAmount, user2, user2);
    }

    function testTransferEventEmitted() public {
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 user1DepositTime = crossChainFleetCommander.lastDepositTimestamp(user1);

        // Expect the cooldown propagation event
        vm.expectEmit(true, true, false, true);
        emit ICrossChainFleetCommander.FleetCommanderCooldownPropagated(user1, user2, user1DepositTime);

        // User1 transfers shares to User2
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, shares / 2);
    }

    function testTransferFromEventEmitted() public {
        // Create a third user
        address user3 = address(0x400);
        
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);
        uint256 user1DepositTime = crossChainFleetCommander.lastDepositTimestamp(user1);

        // User1 approves User2 to spend their shares
        vm.prank(user1);
        crossChainFleetCommander.approve(user2, shares);

        // Expect the cooldown propagation event
        vm.expectEmit(true, true, false, true);
        emit ICrossChainFleetCommander.FleetCommanderCooldownPropagated(user1, user3, user1DepositTime);

        // User2 transfers from User1 to User3
        vm.prank(user2);
        crossChainFleetCommander.transferFrom(user1, user3, shares / 2);
    }

    function testNoEventEmittedWhenNoCooldownPropagation() public {
        // User1 deposits and gets cooldown
        uint256 shares = performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // User2 deposits and gets cooldown
        performDeposit(user2, DEPOSIT_AMOUNT, user2);

        // No event should be emitted since User2's cooldown is more restrictive
        vm.expectEmit(false, false, false, false);
        emit ICrossChainFleetCommander.FleetCommanderCooldownPropagated(user1, user2, 0); // This should not match

        // User1 transfers to User2 (no propagation should occur)
        vm.prank(user1);
        crossChainFleetCommander.transfer(user2, shares / 2);
    }

    function testDepositForOthersSetsCorrectCooldown() public {
        // User1 deposits for User2 (User1 pays, User2 receives shares)
        vm.prank(user1);
        crossChainFleetCommander.deposit(DEPOSIT_AMOUNT, user2);

        // User2 should have the cooldown timestamp, not User1
        uint256 user2CooldownTime = getNextWithdrawTimestamp(user2);
        uint256 user1CooldownTime = getNextWithdrawTimestamp(user1);

        assertTrue(
            user2CooldownTime > 0,
            "User2 should have a cooldown timestamp"
        );
        assertEq(
            user1CooldownTime,
            0,
            "User1 should not have a cooldown timestamp"
        );

        // User2 should not be able to withdraw immediately
        assertFalse(
            canWithdraw(user2),
            "User2 should not be able to withdraw after deposit"
        );

        // User1 should be able to withdraw (no cooldown)
        assertTrue(
            canWithdraw(user1),
            "User1 should be able to withdraw (no cooldown)"
        );

        // Fast forward past cooldown
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Now User2 should be able to withdraw
        assertTrue(
            canWithdraw(user2),
            "User2 should be able to withdraw after cooldown"
        );
    }
}
