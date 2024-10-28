// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";

import {CooldownEnforcer_TestBase} from "./CooldownEnforcerTestBase.sol";

/**
 * Specialization to start the cooldown from the deployment time
 */
contract CooldownEnforcer_NoInitialCooldown_Test is CooldownEnforcer_TestBase {
    function enforceFromNow() public pure override returns (bool) {
        return false;
    }
}

/**
 * CooldownEnforce.enforceCooldown modifier tests
 */
contract CooldownEnforcer_EnforceCooldown_NoInitialCooldown_Test is
    CooldownEnforcer_NoInitialCooldown_Test
{
    function test_CooldownInThePast_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp - 100);

        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, initialCooldown);
    }

    function test_CooldownRightNow_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp);

        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, initialCooldown);
    }

    function test_CooldownInTheFuture_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + 100);

        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, initialCooldown);
    }

    /**
     * CooldownEnforcer with initial timestamp set to deploy timestamp
     */
    function test_SuccessiveEnforcings_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp - 5);

        // ROUND 1
        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 2
        vm.warp(lastActionTimestamp + initialCooldown);

        cooldownEnforcer.doEnforceCooldown();

        lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 3
        vm.warp(lastActionTimestamp + initialCooldown);

        cooldownEnforcer.doEnforceCooldown();

        lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 4: will revert
        vm.warp(lastActionTimestamp + initialCooldown - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                lastActionTimestamp,
                initialCooldown,
                block.timestamp
            )
        );

        cooldownEnforcer.doEnforceCooldown();
    }
}

/**
 * CooldownEnforce._updateCooldown tests
 */
contract CooldownEnforcer_UpdateCooldown_InitialCooldown_Test is
    CooldownEnforcer_NoInitialCooldown_Test
{
    function test_UpdateCooldown_ShouldSucceed() public {
        vm.revertTo(snapshotId);

        cooldownEnforcer.updateCooldown(updatedCooldown);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, updatedCooldown);
    }
}
