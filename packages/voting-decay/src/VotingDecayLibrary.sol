// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";

/*
 * @title VotingDecayLibrary
 * @notice A library for managing voting power decay calculations
 * @dev Provides functions for calculating decay indices and applying decay to voting power
 */
library VotingDecayLibrary {
    using Math for uint256;

    /* @notice Constant representing 1 in ray precision (27 decimal places) */
    uint256 public constant RAY = 1e27;

    /* @notice Number of seconds in a year */
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /*
     * @notice Structure representing an account's voting decay information
     * @param decayIndex The current decay index of the account
     * @param lastUpdateTimestamp The timestamp of the last update to the account
     * @param decayRate The rate at which the account's voting power decays
     * @param delegateTo The address to which this account has delegated voting power
     * @param decayFreeWindow The duration for which decay is not applied after an update
     */
    struct DecayInfo {
        uint256 decayIndex;
        uint256 lastUpdateTimestamp;
        uint256 decayRate;
        address delegateTo;
        uint256 decayFreeWindow;
    }

    /*
     * @notice Calculates the new decay index based on the elapsed time and decay rate
     * @param currentIndex The current decay index
     * @param elapsedTime The time elapsed since the last update
     * @param decayRate The rate of decay
     * @param decayFreeWindow The duration for which decay is not applied
     * @return The new decay index
     */
    function calculateDecayIndex(
        uint256 currentIndex,
        uint256 elapsedTime,
        uint256 decayRate,
        uint256 decayFreeWindow
    ) internal pure returns (uint256) {
        if (elapsedTime <= decayFreeWindow) {
            return currentIndex;
        }
        uint256 decayTime = elapsedTime - decayFreeWindow;
        uint256 yearFraction = (decayTime * RAY) / SECONDS_PER_YEAR;
        uint256 decayFactor = RAY - ((yearFraction * decayRate) / RAY);
        return (currentIndex * decayFactor) / RAY;
    }

    /*
     * @notice Applies the decay index to the original voting power
     * @param originalVotingPower The original voting power before decay
     * @param decayIndex The current decay index
     * @return The decayed voting power
     */
    function applyDecayToVotingPower(
        uint256 originalVotingPower,
        uint256 decayIndex
    ) internal pure returns (uint256) {
        return (originalVotingPower * decayIndex) / RAY;
    }

    /*
     * @notice Checks if a given decay rate is valid
     * @param rate The decay rate to check
     * @return True if the rate is valid, false otherwise
     */
    function isValidDecayRate(uint256 rate) internal pure returns (bool) {
        return rate <= RAY;
    }
}
