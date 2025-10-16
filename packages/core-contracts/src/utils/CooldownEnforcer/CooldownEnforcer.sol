// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ICooldownEnforcer} from "./ICooldownEnforcer.sol";

import "./ICooldownEnforcerErrors.sol";
import "./ICooldownEnforcerEvents.sol";

/**
 * @title CooldownEnforcer
 * @custom:see ICooldownEnforcer
 * @notice Handles both rebalance cooldowns and user deposit cooldowns
 */
abstract contract CooldownEnforcer is ICooldownEnforcer {
    /**
     * STATE VARIABLES
     */

    /**
     * Cooldown between rebalance actions in seconds
     */
    uint256 private _rebalanceCooldown;

    /**
     * Timestamp of the last rebalance action in Epoch time (block timestamp)
     */
    uint256 private _lastRebalanceTimestamp;

    /**
     * @notice The minimum duration that the contract must remain paused
     */
    uint256 private constant MINIMUM_COOLDOWN_TIME_SECONDS = 1 minutes;

    /**
     * @notice The maximum duration that the contract can enforce
     */
    uint256 private constant MAXIMUM_COOLDOWN_TIME_SECONDS = 1 days;

    /**
     * CONSTRUCTOR
     */

    /**
     * @notice Initializes the rebalance cooldown period and sets the last action timestamp to the current block timestamp
     *         if required
     *
     * @param rebalanceCooldown_ The cooldown period for rebalance operations in seconds.
     * @param enforceFromNow If true, the last action timestamp is set to the current block timestamp.
     *
     * @dev The last action timestamp is set to the current block timestamp if enforceFromNow is true,
     *      otherwise it is set to 0 signaling that the cooldown period has not started yet.
     *      Rebalance cooldown must meet minimum requirements.
     */
    constructor(uint256 rebalanceCooldown_, bool enforceFromNow) {
        if (rebalanceCooldown_ < MINIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooShort();
        }
        if (rebalanceCooldown_ > MAXIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooLong();
        }

        _rebalanceCooldown = rebalanceCooldown_;

        if (enforceFromNow) {
            _lastRebalanceTimestamp = block.timestamp;
        }
    }

    /**
     * MODIFIERS
     */

    /**
     * @notice Modifier to enforce the rebalance cooldown period between rebalance actions.
     *
     * @dev If the cooldown period has not elapsed, the function call will revert.
     *      Otherwise, the last rebalance timestamp is updated to the current block timestamp.
     */
    modifier enforceRebalanceCooldown() {
        if (block.timestamp - _lastRebalanceTimestamp < _rebalanceCooldown) {
            revert CooldownNotElapsed(
                _lastRebalanceTimestamp,
                _rebalanceCooldown,
                block.timestamp
            );
        }

        // Update the last rebalance timestamp to the current block timestamp
        // before executing the function so it acts as a reentrancy guard
        // by not allowing a second call to execute
        _lastRebalanceTimestamp = block.timestamp;
        _;
    }

    /**
     * VIEW FUNCTIONS
     */

    /// @inheritdoc ICooldownEnforcer
    function getCooldown() public view returns (uint256) {
        return _rebalanceCooldown;
    }

    /// @inheritdoc ICooldownEnforcer
    function getLastActionTimestamp() public view returns (uint256) {
        return _lastRebalanceTimestamp;
    }

    /**
     * INTERNAL STATE CHANGE FUNCTIONS
     */

    /**
     * @notice Updates the rebalance cooldown period.
     *
     * @param newCooldown The new rebalance cooldown period in seconds.
     *
     * @dev The function is internal so it can be wrapped with access modifiers if needed
     */
    function _updateRebalanceCooldown(uint256 newCooldown) internal {
        if (newCooldown < MINIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooShort();
        }
        if (newCooldown > MAXIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooLong();
        }
        emit CooldownUpdated(_rebalanceCooldown, newCooldown);

        _rebalanceCooldown = newCooldown;
    }

    /**
     * @notice Resets the last rebalance timestamp
     * @dev Allows for cooldown period to be skipped (IE after force withdrawal)
     */
    function _resetLastRebalanceTimestamp() internal {
        _lastRebalanceTimestamp = 0;
    }
}
