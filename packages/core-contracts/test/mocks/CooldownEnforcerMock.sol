// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {CooldownEnforcer} from "../../src/utils/CooldownEnforcer/CooldownEnforcer.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/** Mock contract to use the abstract contract CooldownEnforcer */
contract CooldownEnforcerMock is Initializable, CooldownEnforcer {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        uint256 cooldown_,
        bool enforceFromNow
    ) public initializer {
        CooldownEnforcer.__CooldownEnforcer_init(cooldown_, enforceFromNow);
    }

    function updateCooldown(uint256 cooldown_) external {
        _updateCooldown(cooldown_);
    }

    function doEnforceCooldown() external enforceCooldown {
        // no-op
    }
}
