// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {UD60x18, ud, unwrap} from "@prb/math/src/UD60x18.sol";

/*
 * @title VotingDecayMath
 * @notice A library for advanced mathematical operations used in voting decay calculations
 * @dev Utilizes PRBMath for precise calculations
 */
library VotingDecayMath {
    /* @notice Constant representing the scale factor for calculations (18 decimal places) */
    uint256 private constant WAD = 1e18;

    /**
     * @dev Multiplies two numbers and divides the result by a third number, using PRBMath for precision.
     * @param a The first number to multiply
     * @param b The second number to multiply
     * @param denominator The number to divide by
     * @return The result of (a * b) / denominator, using PRBMath's UD60x18 type
     */
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256) {
        UD60x18 result = ud(a).mul(ud(b)).div(ud(denominator));
        return unwrap(result);
    }

    /**
     * @dev Calculates the exponential decay using PRBMath's UD60x18 type.
     * @param initialValue The initial value
     * @param decayRatePerSecond The decay rate per second
     * @param decayTimeInSeconds The time elapsed in seconds
     * @return The decayed value
     */
    function exponentialDecay(
        uint256 initialValue,
        uint256 decayRatePerSecond,
        uint256 decayTimeInSeconds
    ) internal pure returns (uint256) {
        // Early returns
        if (decayTimeInSeconds == 0 || decayRatePerSecond == 0) {
            return initialValue;
        }
        if (decayRatePerSecond >= WAD) {
            return 0;
        }
        if (initialValue == 0) {
            return 0;
        }

        // Safe conversion to UD60x18
        UD60x18 retentionRatePerSecond;
        unchecked {
            // WAD - decayRatePerSecond is safe because we checked decayRatePerSecond < WAD
            retentionRatePerSecond = ud(WAD - decayRatePerSecond);
        }

        // If retention rate is 0 or time is too large, return 0
        if (
            unwrap(retentionRatePerSecond) == 0 ||
            decayTimeInSeconds > type(uint32).max
        ) {
            return 0;
        }

        UD60x18 retentionFactor = retentionRatePerSecond.powu(
            decayTimeInSeconds
        );

        // If retention factor became 0 during calculation
        if (unwrap(retentionFactor) == 0) {
            return 0;
        }

        UD60x18 result = ud(initialValue).mul(retentionFactor);

        return unwrap(result.gt(ud(0)) ? result.div(ud(WAD)) : ud(0));
    }

    /**
     * @dev Calculates the linear decay.
     * @param initialValue The initial value
     * @param decayRatePerSecond The decay rate per second
     * @param decayTimeInSeconds The time elapsed in seconds
     * @return The decayed value
     */
    function linearDecay(
        uint256 initialValue,
        uint256 decayRatePerSecond,
        uint256 decayTimeInSeconds
    ) internal pure returns (uint256) {
        // Early returns
        if (decayTimeInSeconds == 0 || decayRatePerSecond == 0) {
            return initialValue;
        }
        if (decayRatePerSecond >= WAD) {
            return 0;
        }
        if (initialValue == 0) {
            return 0;
        }

        // Check for overflow in multiplication
        if (
            decayRatePerSecond > 0 &&
            decayTimeInSeconds > WAD / decayRatePerSecond
        ) {
            return 0;
        }

        uint256 totalDecayFactor;
        unchecked {
            // Safe because of the check above
            totalDecayFactor = decayRatePerSecond * decayTimeInSeconds;
        }

        // Check if total decay exceeds 100%
        if (totalDecayFactor >= WAD) {
            return 0;
        }

        uint256 retentionFactor;
        unchecked {
            // Safe because we checked totalDecayFactor < WAD
            retentionFactor = WAD - totalDecayFactor;
        }

        // Final multiplication and division
        return (initialValue * retentionFactor) / WAD;
    }
}
