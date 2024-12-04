// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CooldownEnforcerMock} from "../../mocks/CooldownEnforcerMock.sol";
import {Test, console} from "forge-std/Test.sol";

/**
 * @title CooldownEnforcerTestBase
 * @notice Base contract for all CooldownEnforcer tests
 */
abstract contract CooldownEnforcer_TestBase is Test {
    CooldownEnforcerMock public cooldownEnforcer;

    uint256 initialCooldown = 1 minutes;
    uint256 updatedCooldown = 20 minutes;

    uint256 initialTimestamp = 20000;
    uint256 snapshotId;

    function setUp() public {
        vm.warp(initialTimestamp);

        cooldownEnforcer = new CooldownEnforcerMock(
            initialCooldown,
            this.enforceFromNow()
        );

        snapshotId = vm.snapshot();
    }

    function enforceFromNow() public view virtual returns (bool);
}
