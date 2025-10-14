// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * EVENTS
 */

/**
 * @param previousCooldown The previous cooldown period in seconds.
 * @param newCooldown The new cooldown period in seconds.
 */
event CooldownUpdated(uint256 previousCooldown, uint256 newCooldown);

/**
 * @notice Emitted when cooldown timestamp is propagated from sender to recipient
 * @param from The address that sent the shares
 * @param to The address that received the shares
 * @param cooldownTimestamp The cooldown timestamp that was propagated
 */
event UserCooldownPropagated(
    address indexed from,
    address indexed to,
    uint256 cooldownTimestamp
);
