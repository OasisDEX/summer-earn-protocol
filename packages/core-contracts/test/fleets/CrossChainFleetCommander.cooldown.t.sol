// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {FleetCommanderWithCooldownTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {FleetCommander} from "../../src/contracts/FleetCommander.sol";
import {ICrossChainFleetCommanderErrors} from "../../src/errors/ICrossChainFleetCommanderErrors.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title FleetCommander Cooldown Tests
 * @notice Test suite for cooldown functionality in FleetCommander
 * @dev Tests cooldown enforcement, deposit tracking, and MEV protection
 */
contract FleetCommanderCooldownTest is
    FleetCommanderWithCooldownTestBase
{
    uint256 constant INITIAL_TIP_RATE = 5; // 5%
    uint256 constant DEPOSIT_AMOUNT = 10000 * 10 ** 6; // 10,000 USDC
    uint256 constant WITHDRAWAL_AMOUNT = 5000 * 10 ** 6; // 5,000 USDC

    function setUp() public {
        initializeFleetCommanderWithCooldown(INITIAL_TIP_RATE);
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
        fleetCommanderWithCooldown.withdraw(WITHDRAWAL_AMOUNT, user1, user1);
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
        fleetCommanderWithCooldown.redeem(shares / 2, user1, user1);
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
        uint256 firstDepositTime = block.timestamp;

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
}
