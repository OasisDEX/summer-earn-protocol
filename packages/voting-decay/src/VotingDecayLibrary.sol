// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "./VotingDecayMath.sol";

/*
 * @title VotingDecayLibrary
 * @notice A library for managing voting power decay in governance systems
 * @dev Utilizes VotingDecayMath for decay calculations
 */
library VotingDecayLibrary {
    using VotingDecayMath for uint256;

    /* @notice Constant representing 1 in the system's fixed-point arithmetic (18 decimal places) */
    uint256 public constant WAD = 1e18;

    /* @notice Number of seconds in a year, used for annualized rate calculations */
    uint256 private constant SECONDS_PER_YEAR = 365 days;

    /* @notice Enumeration of supported decay function types */
    enum DecayFunction {
        Linear,
        Exponential
    }

    /*
     * @notice Structure to store decay information for an account
     * @param retentionFactor The current retention factor of the account's voting power
     * @param lastUpdateTimestamp The timestamp of the last update to the account's decay info
     * @param delegateTo The address to which this account has delegated its voting power, if any
     */
    struct DecayInfo {
        uint256 retentionFactor;
        uint40 lastUpdateTimestamp;
        address delegateTo;
    }

    /*
     * @notice Calculates the new retention factor based on elapsed time and decay parameters
     * @param currentRetentionFactor The current retention factor
     * @param elapsedSeconds The number of seconds elapsed since the last update
     * @param decayRatePerSecond The decay rate per second
     * @param decayFreeWindow The duration (in seconds) during which no decay occurs
     * @param decayFunction The type of decay function to use (Linear or Exponential)
     * @return The newly calculated retention factor
     */
    function calculateRetentionFactor(
        uint256 currentRetentionFactor,
        uint256 elapsedSeconds,
        uint256 decayRatePerSecond,
        uint256 decayFreeWindow,
        DecayFunction decayFunction
    ) internal pure returns (uint256) {
        if (elapsedSeconds <= decayFreeWindow) return currentRetentionFactor;

        uint256 decayTime = elapsedSeconds - decayFreeWindow;

        if (decayFunction == DecayFunction.Linear) {
            return
                currentRetentionFactor.linearDecay(
                    decayRatePerSecond,
                    decayTime
                );
        } else {
            return
                currentRetentionFactor.exponentialDecay(
                    decayRatePerSecond,
                    decayTime
                );
        }
    }

    /*
     * @notice Applies the decay to the original voting power value
     * @param originalValue The original voting power value
     * @param retentionFactor The current retention factor
     * @return The decayed voting power value
     */
    function applyDecay(
        uint256 originalValue,
        uint256 retentionFactor
    ) internal pure returns (uint256) {
        return VotingDecayMath.mulDiv(originalValue, retentionFactor, WAD);
    }

    /*
     * @notice Checks if a given decay rate is valid
     * @param rate The decay rate to check
     * @return A boolean indicating whether the rate is valid (less than or equal to WAD)
     */
    function isValidDecayRate(uint256 rate) internal pure returns (bool) {
        return rate <= WAD;
    }
}
