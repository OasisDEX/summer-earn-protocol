// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";
import {UD60x18, ud, unwrap} from "@prb/math/src/UD60x18.sol";

/*
 * @title VotingDecayMath
 * @notice A library for advanced mathematical operations used in voting decay calculations
 * @dev Utilizes OpenZeppelin's Math library and PRBMath for precise calculations
 */
library VotingDecayMath {
    using Math for uint256;

    /* @notice Constant representing the scale factor for calculations (18 decimal places) */
    uint256 private constant SCALE = 1e18;

    /**
     * @dev Multiplies two numbers and divides the result by a third number, rounding down.
     * @param a The first number to multiply
     * @param b The second number to multiply
     * @param denominator The number to divide by
     * @return The result of (a * b) / denominator, rounded down
     */
    function mulDiv(
        uint256 a,
        uint256 b,
        uint256 denominator
    ) internal pure returns (uint256) {
        return Math.mulDiv(a, b, denominator);
    }

    /**
     * @dev Calculates the exponential decay using PRBMath's UD60x18 type.
     * @param initialValue The initial value
     * @param decayRate The decay rate per second (scaled by 1e18)
     * @param time The time elapsed in seconds
     * @return The decayed value
     */
    function exponentialDecay(
        uint256 initialValue,
        uint256 decayRate,
        uint256 time
    ) internal pure returns (uint256) {
        if (time == 0 || decayRate == 0) {
            return initialValue;
        }

        UD60x18 initialValueUD = ud(initialValue);
        UD60x18 decayRateUD = ud(SCALE - decayRate);
        UD60x18 timeUD = ud(time);

        UD60x18 decayFactor = decayRateUD.pow(timeUD);
        UD60x18 result = initialValueUD.mul(decayFactor);

        return unwrap(result);
    }

    /**
     * @dev Calculates the linear decay.
     * @param initialValue The initial value
     * @param decayRate The decay rate per second (scaled by 1e18)
     * @param time The time elapsed in seconds
     * @return The decayed value
     */
    function linearDecay(
        uint256 initialValue,
        uint256 decayRate,
        uint256 time
    ) internal pure returns (uint256) {
        UD60x18 totalDecay = ud(decayRate).mul(ud(time));
        UD60x18 result = ud(initialValue).sub(totalDecay);
        return unwrap(result.gt(ud(0)) ? result : ud(0));
    }

    /**
     * @dev Calculates the square root of a number using PRBMath's sqrt.
     * @param x The number to calculate the square root of
     * @return y The square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256) {
        return unwrap(ud(x).sqrt());
    }

    /**
     * @dev Raises a number to a power using PRBMath's UD60x18 type.
     * @param base The base number (scaled by 1e18)
     * @param exponent The exponent (integer value)
     * @return The result of base^exponent, scaled by 1e18
     */
    function pow(
        uint256 base,
        uint256 exponent
    ) internal pure returns (uint256) {
        return unwrap(ud(base).powu(exponent));
    }

    /**
     * @dev Calculates the minimum of two numbers.
     * @param a The first number
     * @param b The second number
     * @return The minimum of a and b
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.min(a, b);
    }

    /**
     * @dev Calculates the maximum of two numbers.
     * @param a The first number
     * @param b The second number
     * @return The maximum of a and b
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return Math.max(a, b);
    }
}
