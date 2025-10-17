// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title FleetCommanderPausable
/// @notice An abstract contract that extends OpenZeppelin's Pausable with a minimum pause time functionality
/// @dev This contract should be inherited by other contracts that require a minimum pause duration
abstract contract FleetCommanderPausable is Pausable {
    /// @notice The timestamp when the contract was last paused
    uint256 public pauseStartTime;

    /// @notice The minimum duration that the contract must remain paused
    uint256 constant MINIMUM_PAUSE_TIME_SECONDS = 2 days;

    /// @notice Error thrown when trying to unpause before the minimum pause time has elapsed
    error FleetCommanderPausableMinimumPauseTimeNotElapsed();

    /**
     * @notice Internal function to pause the contract
     * @dev Overrides the _pause function from OpenZeppelin's Pausable
     */
    function _pause() internal override {
        super._pause();
        pauseStartTime = block.timestamp;
    }

    /**
     * @notice Internal function to unpause the contract
     * @dev Overrides the _unpause function from OpenZeppelin's Pausable
     * @dev Reverts if the minimum pause time has not elapsed
     */
    function _unpause() internal override {
        if (block.timestamp < pauseStartTime + MINIMUM_PAUSE_TIME_SECONDS) {
            revert FleetCommanderPausableMinimumPauseTimeNotElapsed();
        }
        super._unpause();
    }
}
