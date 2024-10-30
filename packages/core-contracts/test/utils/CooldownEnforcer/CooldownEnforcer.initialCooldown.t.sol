// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";

import {CooldownEnforcer_TestBase} from "./CooldownEnforcerTestBase.sol";

/**
 * Specialization to start the cooldown from the deployment time
 */
contract CooldownEnforcer_InitialCooldown_Test is CooldownEnforcer_TestBase {
    function enforceFromNow() public pure override returns (bool) {
        return true;
    }
}

/**
 * CooldownEnforce.enforceCooldown modifier tests
 */
contract CooldownEnforcer_InitialCooldown_EnforceCooldown_InitialCooldown_Test is
    CooldownEnforcer_InitialCooldown_Test
{
    function test_CooldownNotMet_ShouldRevert() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + 5);
        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                initialTimestamp,
                initialCooldown,
                initialTimestamp + 5
            )
        );

        cooldownEnforcer.doEnforceCooldown();
    }

    function test_CooldownAlmostMet_ShouldRevert() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + initialCooldown - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                initialTimestamp,
                initialCooldown,
                initialTimestamp + initialCooldown - 1
            )
        );

        cooldownEnforcer.doEnforceCooldown();
    }

    function test_CooldownExactlyMet_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + initialCooldown);

        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, initialCooldown);
    }

    function test_CooldownMoreThanMet_ShouldSucceed() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + initialCooldown + 1);

        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, initialCooldown);
    }

    function test_SuccessiveEnforcings_ShouldEventuallyRevert() public {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + initialCooldown);

        // ROUND 1
        cooldownEnforcer.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();
        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 2
        vm.warp(initialTimestamp + 2 * initialCooldown);

        cooldownEnforcer.doEnforceCooldown();

        lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();
        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 3
        vm.warp(initialTimestamp + 3 * initialCooldown);

        cooldownEnforcer.doEnforceCooldown();
        lastActionTimestamp = cooldownEnforcer.getLastActionTimestamp();

        assertEq(lastActionTimestamp, block.timestamp);

        // ROUND 4: will revert
        vm.warp(initialTimestamp + 4 * initialCooldown - 1);
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
    CooldownEnforcer_InitialCooldown_Test
{
    function test_UpdateCooldown_ShouldSucceed() public {
        vm.revertTo(snapshotId);

        cooldownEnforcer.updateCooldown(updatedCooldown);

        uint256 cooldown = cooldownEnforcer.getCooldown();

        assertEq(cooldown, updatedCooldown);
    }
}
