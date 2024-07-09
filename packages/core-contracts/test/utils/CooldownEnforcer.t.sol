// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CooldownEnforcer} from "../../src/utils/CooldownEnforcer/CooldownEnforcer.sol";
import "../../src/utils/CooldownEnforcer/ICooldownEnforcerErrors.sol";
import "../../src/utils/CooldownEnforcer/ICooldownEnforcerEvents.sol";

/** Mock contract to use the abstract contract CooldownEnforcer */
contract CooldownEnforcerMock is CooldownEnforcer {
    constructor(
        uint256 cooldown_,
        bool enforceFromNow
    ) CooldownEnforcer(cooldown_, enforceFromNow) {
        // no-op
    }

    function updateCooldown(uint256 cooldown_) external {
        _updateCooldown(cooldown_);
    }

    function doEnforceCooldown() external enforceCooldown {
        // no-op
    }
}

contract CooldownEnforcerTest is Test {
    CooldownEnforcerMock public cooldownEnforcerInitialCooldown;
    CooldownEnforcerMock public cooldownEnforcerNotInitialCooldown;

    uint256 initialCooldown = 10;
    uint256 updatedCooldown = 20;

    uint256 initialTimestamp = 20000;
    uint256 snapshotId;

    function setUp() public {
        vm.warp(initialTimestamp);

        cooldownEnforcerInitialCooldown = new CooldownEnforcerMock(
            initialCooldown,
            true
        );
        cooldownEnforcerNotInitialCooldown = new CooldownEnforcerMock(
            initialCooldown,
            false
        );

        snapshotId = vm.snapshot();
    }

    /** CooldownEnforcer with initial timestamp set to 0 */
    function testEnforceCooldown_InitialCooldown_ShouldRevert() public {
        // TEST 1
        {
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

            cooldownEnforcerInitialCooldown.doEnforceCooldown();
        }

        // TEST 2
        {
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

            cooldownEnforcerInitialCooldown.doEnforceCooldown();
        }
    }

    function testEnforceCooldown_InitialCooldown_ShouldSucceed() public {
        // TEST 1
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + initialCooldown);

            cooldownEnforcerInitialCooldown.doEnforceCooldown();

            uint256 lastActionTimestamp = cooldownEnforcerInitialCooldown
                .getLastActionTimestamp();

            assertEq(lastActionTimestamp, initialTimestamp + initialCooldown);

            uint256 cooldown = cooldownEnforcerInitialCooldown.getCooldown();

            assertEq(cooldown, initialCooldown);
        }

        // TEST 2
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + initialCooldown + 1);

            cooldownEnforcerInitialCooldown.doEnforceCooldown();

            uint256 lastActionTimestamp = cooldownEnforcerInitialCooldown
                .getLastActionTimestamp();

            assertEq(
                lastActionTimestamp,
                initialTimestamp + initialCooldown + 1
            );

            uint256 cooldown = cooldownEnforcerInitialCooldown.getCooldown();

            assertEq(cooldown, initialCooldown);
        }
    }

    function testUpdateCooldown_InitialCooldown_ShouldEventuallyRevert()
        public
    {
        vm.revertTo(snapshotId);
        vm.warp(initialTimestamp + initialCooldown);

        // ROUND 1
        cooldownEnforcerInitialCooldown.doEnforceCooldown();

        uint256 lastActionTimestamp = cooldownEnforcerInitialCooldown
            .getLastActionTimestamp();

        assertEq(lastActionTimestamp, initialTimestamp + initialCooldown);

        // ROUND 2
        vm.warp(initialTimestamp + 2 * initialCooldown);

        cooldownEnforcerInitialCooldown.doEnforceCooldown();

        lastActionTimestamp = cooldownEnforcerInitialCooldown
            .getLastActionTimestamp();

        assertEq(lastActionTimestamp, initialTimestamp + 2 * initialCooldown);

        // ROUND 3
        vm.warp(initialTimestamp + 3 * initialCooldown);

        cooldownEnforcerInitialCooldown.doEnforceCooldown();

        lastActionTimestamp = cooldownEnforcerInitialCooldown
            .getLastActionTimestamp();

        assertEq(lastActionTimestamp, initialTimestamp + 3 * initialCooldown);

        // ROUND 4: will revert
        vm.warp(initialTimestamp + 4 * initialCooldown - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                CooldownNotElapsed.selector,
                initialTimestamp + 3 * initialCooldown,
                initialCooldown,
                initialTimestamp + 4 * initialCooldown - 1
            )
        );

        cooldownEnforcerInitialCooldown.doEnforceCooldown();
    }

    function testSucessiveEnforcements_InitialCooldown_ShouldSucceed() public {
        // TEST 1
        {
            vm.revertTo(snapshotId);

            cooldownEnforcerNotInitialCooldown.updateCooldown(updatedCooldown);

            uint256 cooldown = cooldownEnforcerNotInitialCooldown.getCooldown();

            assertEq(cooldown, updatedCooldown);
        }
    }

    // /** CooldownEnforcer with initial timestamp set to deploy timestamp */

    function testEnforceCooldown_NotInitialCooldown_ShouldSucceed() public {
        // TEST 1
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + 5);

            cooldownEnforcerNotInitialCooldown.doEnforceCooldown();
        }

        // TEST 2
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + initialCooldown - 1);

            cooldownEnforcerNotInitialCooldown.doEnforceCooldown();
        }

        // TEST 3
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + initialCooldown);

            cooldownEnforcerNotInitialCooldown.doEnforceCooldown();

            uint256 lastActionTimestamp = cooldownEnforcerNotInitialCooldown
                .getLastActionTimestamp();

            assertEq(lastActionTimestamp, initialTimestamp + initialCooldown);

            uint256 cooldown = cooldownEnforcerNotInitialCooldown.getCooldown();

            assertEq(cooldown, initialCooldown);
        }

        // TEST 4
        {
            vm.revertTo(snapshotId);
            vm.warp(initialTimestamp + initialCooldown + 1);

            cooldownEnforcerNotInitialCooldown.doEnforceCooldown();

            uint256 lastActionTimestamp = cooldownEnforcerNotInitialCooldown
                .getLastActionTimestamp();

            assertEq(
                lastActionTimestamp,
                initialTimestamp + initialCooldown + 1
            );

            uint256 cooldown = cooldownEnforcerNotInitialCooldown.getCooldown();

            assertEq(cooldown, initialCooldown);
        }
    }

    function testUpdateCooldown_NotInitialCooldown_ShouldSucceed() public {
        // TEST 1
        {
            vm.revertTo(snapshotId);

            vm.expectEmit();
            emit CooldownUpdated(initialCooldown, updatedCooldown);

            cooldownEnforcerNotInitialCooldown.updateCooldown(updatedCooldown);

            uint256 cooldown = cooldownEnforcerNotInitialCooldown.getCooldown();

            assertEq(cooldown, updatedCooldown);
        }
    }
}
