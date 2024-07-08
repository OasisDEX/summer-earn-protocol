// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title ICooldownEnforcerEvents
 * @custom:see ICooldownEnforcer
 */
interface ICooldownEnforcerEvents {
    /** EVENTS */

    /**
     *
     * @param newCooldown New rebalance cooldown period
     */
    event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);
}
