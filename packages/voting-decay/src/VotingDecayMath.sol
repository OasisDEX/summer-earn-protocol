// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

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
        if (decayTimeInSeconds == 0 || decayRatePerSecond == 0) {
            return initialValue;
        }

        UD60x18 retentionRatePerSecond = ud(WAD - decayRatePerSecond);
        UD60x18 retentionFactor = retentionRatePerSecond.powu(
            decayTimeInSeconds
        );
        UD60x18 result = ud(initialValue).mul(retentionFactor);

        return unwrap(result.gt(ud(0)) ? result.div(ud(1e18)) : ud(0));
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
        uint256 totalDecayFactor = decayRatePerSecond * decayTimeInSeconds;
        uint256 retentionFactor = WAD - totalDecayFactor;

        return (initialValue * retentionFactor) / WAD;
    }
}
