// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CooldownEnforcer} from "./CooldownEnforcer.sol";
import {ICooldownEnforcer} from "./ICooldownEnforcer.sol";

import "./ICooldownEnforcerErrors.sol";
import "./ICooldownEnforcerEvents.sol";

/**
 * @title UserCooldownEnforcer
 * @notice Extends CooldownEnforcer to support per-user cooldowns
 * @dev This contract provides both global cooldown functionality (inherited from CooldownEnforcer)
 *      and per-user cooldown functionality for MEV protection
 */
abstract contract UserCooldownEnforcer is CooldownEnforcer {
    /**
     * STATE VARIABLES
     */

    /**
     * @notice Mapping of user address to their last action timestamp
     * @dev Used to track when each user last performed an action that triggers cooldown
     */
    mapping(address => uint256) private _userLastActionTimestamps;

    /**
     * @notice User-specific cooldown period in seconds
     * @dev If 0, uses the global cooldown period from CooldownEnforcer
     */
    uint256 private _userCooldownPeriod;

    /**
     * CONSTRUCTOR
     */

    /**
     * @notice Initializes the UserCooldownEnforcer contract
     * @param cooldown_ The cooldown period in seconds for the global cooldown
     * @param enforceFromNow If true, the last action timestamp is set to the current block timestamp
     */
    constructor(
        uint256 cooldown_,
        bool enforceFromNow
    ) CooldownEnforcer(cooldown_, enforceFromNow) {}

    /**
     * MODIFIERS
     */

    /**
     * @notice Modifier to enforce cooldown period for a specific user
     * @param user The user address to check cooldown for
     * @dev If the user's cooldown period has not elapsed, the function call will revert.
     *      Otherwise, the user's last action timestamp is updated to the current block timestamp.
     */
    modifier enforceUserCooldown(address user) {
        uint256 userCooldown = _userCooldownPeriod > 0
            ? _userCooldownPeriod
            : getCooldown();
        uint256 lastAction = _userLastActionTimestamps[user];

        if (lastAction > 0 && block.timestamp - lastAction < userCooldown) {
            revert CooldownNotElapsed(
                lastAction,
                userCooldown,
                block.timestamp
            );
        }

        // Update the user's last action timestamp to the current block timestamp
        // before executing the function so it acts as a reentrancy guard
        _userLastActionTimestamps[user] = block.timestamp;
        _;
    }

    /**
     * VIEW FUNCTIONS
     */

    /**
     * @notice Get user's last action timestamp
     * @param user The user address
     * @return The timestamp of the user's last action
     */
    function getUserLastActionTimestamp(
        address user
    ) public view returns (uint256) {
        return _userLastActionTimestamps[user];
    }

    /**
     * @notice Get the user cooldown period
     * @return The user cooldown period in seconds (returns global cooldown if user cooldown is 0)
     */
    function getUserCooldownPeriod() public view returns (uint256) {
        return _userCooldownPeriod > 0 ? _userCooldownPeriod : getCooldown();
    }

    /**
     * @notice Check if a user can perform an action (cooldown has passed)
     * @param user The user address to check
     * @return True if the user can perform an action, false otherwise
     */
    function canUserPerformAction(address user) public view returns (bool) {
        uint256 lastAction = _userLastActionTimestamps[user];
        if (lastAction == 0) return true;

        uint256 userCooldown = getUserCooldownPeriod();
        if (userCooldown == 0) return true;

        return block.timestamp > lastAction + userCooldown;
    }

    /**
     * @notice Get the timestamp when a user can next perform an action
     * @param user The user address
     * @return The timestamp when the user can next perform an action (0 if no cooldown)
     */
    function getNextUserActionTimestamp(
        address user
    ) public view returns (uint256) {
        uint256 lastAction = _userLastActionTimestamps[user];
        if (lastAction == 0) return 0;

        uint256 userCooldown = getUserCooldownPeriod();
        if (userCooldown == 0) return 0;

        return lastAction + userCooldown;
    }

    /**
     * INTERNAL STATE CHANGE FUNCTIONS
     */

    /**
     * @notice Update user's last action timestamp
     * @param user The user address
     * @dev This function is internal so it can be wrapped with access modifiers if needed
     */
    function _updateUserLastActionTimestamp(address user) internal {
        _userLastActionTimestamps[user] = block.timestamp;
    }

    /**
     * @notice Set user-specific cooldown period
     * @param newCooldown The new cooldown period in seconds
     * @dev The function is internal so it can be wrapped with access modifiers if needed
     * @dev If newCooldown is 0, users will use the global cooldown period
     */
    function _setUserCooldownPeriod(uint256 newCooldown) internal {
        emit CooldownUpdated(_userCooldownPeriod, newCooldown);
        _userCooldownPeriod = newCooldown;
    }

    /**
     * @notice Reset a user's last action timestamp
     * @param user The user address
     * @dev Allows for cooldown period to be skipped for a specific user
     */
    function _resetUserLastActionTimestamp(address user) internal {
        _userLastActionTimestamps[user] = 0;
    }
}
