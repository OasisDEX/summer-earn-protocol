// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/utils/math/Math.sol";

library VotingDecayMath {
    using Math for uint256;

    uint256 private constant SCALE = 1e18;

    /**
     * @dev Multiplies two numbers and divides the result by a third number, rounding down.
     * @param a The first number to multiply
     * @param b The second number to multiply
     * @param denominator The number to divide by
     * @return The result of (a * b) / denominator, rounded down
     */
    function mulDiv(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256) {
        return Math.mulDiv(a, b, denominator);
    }

    /**
     * @dev Calculates the exponential decay.
     * @param initialValue The initial value
     * @param decayRate The decay rate per second (scaled by 1e18)
     * @param time The time elapsed in seconds
     * @return The decayed value
     */
    function exponentialDecay(uint256 initialValue, uint256 decayRate, uint256 time) internal pure returns (uint256) {
        if (time == 0 || decayRate == 0) {
            return initialValue;
        }

        // Calculate decay factor: (1 - decayRate)^time
        uint256 decayFactor = SCALE - decayRate;
        for (uint256 i = 0; i < time; i++) {
            initialValue = mulDiv(initialValue, decayFactor, SCALE);
        }

        return initialValue;
    }

    /**
     * @dev Calculates the linear decay.
     * @param initialValue The initial value
     * @param decayRate The decay rate per second (scaled by 1e18)
     * @param time The time elapsed in seconds
     * @return The decayed value
     */
    function linearDecay(uint256 initialValue, uint256 decayRate, uint256 time) internal pure returns (uint256) {
        uint256 totalDecay = mulDiv(decayRate, time, SCALE);
        return initialValue > totalDecay ? initialValue - totalDecay : 0;
    }

    /**
     * @dev Calculates the square root of a number.
     * @param x The number to calculate the square root of
     * @return y The square root of x
     */
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        return Math.sqrt(x);
    }

    /**
     * @dev Raises a number to a power.
     * @param base The base number
     * @param exponent The exponent
     * @return The result of base^exponent
     */
    function pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        return base.pow(exponent);
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
