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
     * Cooldown between user deposits and withdrawals in seconds
     */
    uint256 private _userDepositCooldown;

    /**
     * Timestamp of the last rebalance action in Epoch time (block timestamp)
     */
    uint256 private _lastRebalanceTimestamp;

    /**
     * Mapping of user addresses to their last deposit timestamp
     * @dev Used to enforce cooldown periods between deposits and withdrawals
     */
    mapping(address user => uint256 timestamp) public lastDepositTimestamp;

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
     * @notice Initializes the cooldown periods and sets the last action timestamp to the current block timestamp
     *         if required
     *
     * @param rebalanceCooldown_ The cooldown period for rebalance operations in seconds.
     * @param userDepositCooldown_ The cooldown period for user deposits in seconds.
     * @param enforceFromNow If true, the last action timestamp is set to the current block timestamp.
     *
     * @dev The last action timestamp is set to the current block timestamp if enforceFromNow is true,
     *      otherwise it is set to 0 signaling that the cooldown period has not started yet.
     *      User deposit cooldown can be 0 (no cooldown), but rebalance cooldown must meet minimum requirements.
     */
    constructor(
        uint256 rebalanceCooldown_,
        uint256 userDepositCooldown_,
        bool enforceFromNow
    ) {
        if (rebalanceCooldown_ < MINIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooShort();
        }
        if (rebalanceCooldown_ > MAXIMUM_COOLDOWN_TIME_SECONDS) {
            revert CooldownEnforcerCooldownTooLong();
        }

        _rebalanceCooldown = rebalanceCooldown_;
        _userDepositCooldown = userDepositCooldown_;

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
     * @notice Modifier to enforce user deposit cooldown period
     * @dev Reverts if the user's last deposit was within the cooldown period
     * @param user The address of the user for whom the cooldown is being enforced
     */
    modifier enforceUserDepositCooldown(address user) {
        if (_userDepositCooldown > 0) {
            uint256 lastDeposit = lastDepositTimestamp[user];
            if (
                lastDeposit > 0 &&
                block.timestamp <= lastDeposit + _userDepositCooldown
            ) {
                revert UserDepositCooldownNotMet(
                    user,
                    block.timestamp,
                    lastDeposit + _userDepositCooldown
                );
            }
        }
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
     * @notice Gets the current user deposit cooldown period
     * @return The current user deposit cooldown period in seconds
     */
    function getUserDepositCooldown() public view returns (uint256) {
        return _userDepositCooldown;
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
     * @notice Updates the user deposit cooldown period.
     *
     * @param newCooldown The new user deposit cooldown period in seconds.
     *
     * @dev The function is internal so it can be wrapped with access modifiers if needed
     *      User deposit cooldown can be 0 (no cooldown)
     */
    function _updateUserDepositCooldown(uint256 newCooldown) internal {
        _userDepositCooldown = newCooldown;
    }

    /**
     * @notice Resets the last rebalance timestamp
     * @dev Allows for cooldown period to be skipped (IE after force withdrawal)
     */
    function _resetLastRebalanceTimestamp() internal {
        _lastRebalanceTimestamp = 0;
    }

    /**
     * @notice Records the deposit timestamp for a user
     * @param user The address of the user who made the deposit
     */
    function _recordDepositTimestamp(address user) internal {
        lastDepositTimestamp[user] = block.timestamp;
    }

    /**
     * @notice Propagates cooldown timestamp from sender to recipient during transfers
     * @param from The address that sent the shares
     * @param to The address that received the shares
     */
    function _propagateCooldownTimestamp(address from, address to) internal {
        uint256 fromCooldownTimestamp = lastDepositTimestamp[from];
        if (fromCooldownTimestamp > 0) {
            lastDepositTimestamp[to] = fromCooldownTimestamp;
            emit UserCooldownPropagated(from, to, fromCooldownTimestamp);
        }
    }
}
