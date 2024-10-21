// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CooldownEnforcer} from "../../src/utils/CooldownEnforcer/CooldownEnforcer.sol";

/**
 * Mock contract to use the abstract contract CooldownEnforcer
 */
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
