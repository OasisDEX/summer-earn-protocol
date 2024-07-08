// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @title ICooldownEnforcerErrors
 * @notice Enforces a cooldown period between actions. It provides the basic management for a cooldown
           period, allows to update the cooldown period and provides a modifier to enforce the cooldown.
 */
interface ICooldownEnforcerErrors {
    /** ERRORS */
    error CooldownNotElapsed(
        uint256 lastActionTimestamp,
        uint256 cooldown,
        uint256 currentTimestamp
    );
}
