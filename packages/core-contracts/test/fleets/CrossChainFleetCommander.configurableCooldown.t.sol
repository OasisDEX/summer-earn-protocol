// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CrossChainFleetCommanderTestBase} from "./CrossChainFleetCommanderTestBase.sol";
import {CrossChainFleetCommander} from "../../src/contracts/CrossChainFleetCommander.sol";
import {IFleetCommanderConfigProviderEvents} from "../../src/events/IFleetCommanderConfigProviderEvents.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @title CrossChainFleetCommander Configurable Cooldown Tests
 * @notice Test suite for configurable cooldown functionality in CrossChainFleetCommander
 * @dev Tests the setCooldownPeriod function and its effects on cooldown behavior
 */
contract CrossChainFleetCommanderConfigurableCooldownTest is
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
                        CONFIGURABLE COOLDOWN TESTS
    //////////////////////////////////////////////////////////////*/

    function testInitialCooldownPeriod() public view {
        assertEq(
            getCooldownPeriod(),
            COOLDOWN_PERIOD,
            "Initial cooldown period should match constructor parameter"
        );
    }

    function testSetCooldownPeriodByCurator() public {
        uint256 newCooldownPeriod = 2 hours;

        // Set new cooldown period as curator
        vm.prank(governor); // governor has curator role
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // Verify cooldown period was updated
        assertEq(
            getCooldownPeriod(),
            newCooldownPeriod,
            "Cooldown period should be updated"
        );
    }

    function testSetCooldownPeriodEvent() public {
        uint256 newCooldownPeriod = 2 hours;

        // Expect event emission
        vm.expectEmit(true, true, true, true);
        emit IFleetCommanderConfigProviderEvents
            .FleetCommanderCooldownPeriodUpdated(newCooldownPeriod);

        // Set new cooldown period
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);
    }

    function testSetCooldownPeriodOnlyCurator() public {
        uint256 newCooldownPeriod = 2 hours;

        // Try to set cooldown period as non-curator (should fail)
        vm.prank(user1);
        vm.expectRevert();
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // Verify cooldown period was not changed
        assertEq(
            getCooldownPeriod(),
            COOLDOWN_PERIOD,
            "Cooldown period should not be changed by non-curator"
        );
    }

    function testSetCooldownPeriodWhenPaused() public {
        uint256 newCooldownPeriod = 2 hours;

        // Pause the contract
        vm.prank(governor);
        crossChainFleetCommander.pause();

        // Try to set cooldown period when paused (should fail)
        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // Wait for minimum pause time to elapse (2 days)
        vm.warp(block.timestamp + 2 days + 1);

        // Unpause and try again (should succeed)
        vm.prank(governor);
        crossChainFleetCommander.unpause();

        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        assertEq(
            getCooldownPeriod(),
            newCooldownPeriod,
            "Cooldown period should be updated after unpause"
        );
    }

    function testCooldownBehaviorWithNewPeriod() public {
        uint256 newCooldownPeriod = 30 minutes; // Shorter cooldown for testing

        // Set new cooldown period
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Check that the new cooldown period is being used
        uint256 nextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertEq(
            nextWithdrawTime,
            block.timestamp + newCooldownPeriod,
            "Next withdraw time should use new cooldown period"
        );

        // Should not be able to withdraw yet
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw before new cooldown period"
        );

        // Fast forward past the new cooldown period
        vm.warp(block.timestamp + newCooldownPeriod + 1);

        // Now should be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after new cooldown period"
        );
    }

    function testCooldownBehaviorWithLongerPeriod() public {
        uint256 newCooldownPeriod = 4 hours; // Longer cooldown

        // Set new cooldown period
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Check that the new cooldown period is being used
        uint256 nextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertEq(
            nextWithdrawTime,
            block.timestamp + newCooldownPeriod,
            "Next withdraw time should use new cooldown period"
        );

        // Should not be able to withdraw yet
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw before new cooldown period"
        );

        // Fast forward past the original cooldown period but not the new one
        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1);

        // Should still not be able to withdraw
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw before new longer cooldown period"
        );

        // Fast forward past the new cooldown period
        vm.warp(block.timestamp + newCooldownPeriod + 1);

        // Now should be able to withdraw
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw after new cooldown period"
        );
    }

    function testCooldownUpdateAffectsExistingUsers() public {
        // User1 deposits with original cooldown period
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Update cooldown period
        uint256 newCooldownPeriod = 2 hours;
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(newCooldownPeriod);

        // User1's next withdraw time should be updated to use new cooldown period
        uint256 updatedNextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertEq(
            updatedNextWithdrawTime,
            block.timestamp + newCooldownPeriod,
            "Next withdraw time should be updated to use new cooldown period"
        );

        // User2 deposits after cooldown update
        performDeposit(user2, DEPOSIT_AMOUNT, user2);
        uint256 user2NextWithdrawTime = getNextWithdrawTimestamp(user2);
        assertEq(
            user2NextWithdrawTime,
            block.timestamp + newCooldownPeriod,
            "New deposits should use updated cooldown period"
        );
    }

    function testZeroCooldownPeriod() public {
        // Set cooldown period to zero
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(0);

        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Should be able to withdraw immediately
        assertTrue(
            canWithdraw(user1),
            "User should be able to withdraw immediately with zero cooldown"
        );

        // Withdrawal should succeed
        performWithdrawal(user1, WITHDRAWAL_AMOUNT, user1, user1);
    }

    function testVeryLongCooldownPeriod() public {
        uint256 veryLongCooldown = 365 days; // 1 year

        // Set very long cooldown period
        vm.prank(governor);
        crossChainFleetCommander.setCooldownPeriod(veryLongCooldown);

        // Perform a deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Should not be able to withdraw for a very long time
        assertFalse(
            canWithdraw(user1),
            "User should not be able to withdraw with very long cooldown"
        );

        uint256 nextWithdrawTime = getNextWithdrawTimestamp(user1);
        assertEq(
            nextWithdrawTime,
            block.timestamp + veryLongCooldown,
            "Next withdraw time should reflect very long cooldown"
        );
    }

    function testMultipleCooldownUpdates() public {
        // Perform initial deposit
        performDeposit(user1, DEPOSIT_AMOUNT, user1);

        // Update cooldown period multiple times
        uint256[] memory cooldownPeriods = new uint256[](3);
        cooldownPeriods[0] = 30 minutes;
        cooldownPeriods[1] = 1 hours;
        cooldownPeriods[2] = 2 hours;

        for (uint256 i = 0; i < cooldownPeriods.length; i++) {
            vm.prank(governor);
            crossChainFleetCommander.setCooldownPeriod(cooldownPeriods[i]);

            assertEq(
                getCooldownPeriod(),
                cooldownPeriods[i],
                "Cooldown period should be updated"
            );
        }

        // Final cooldown period should be the last one set
        assertEq(
            getCooldownPeriod(),
            2 hours,
            "Final cooldown period should be 2 hours"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Helper functions are inherited from CrossChainFleetCommanderTestBase
}
