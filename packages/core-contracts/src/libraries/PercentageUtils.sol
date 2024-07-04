// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../types/Percentage.sol";

/**
 * @title PercentageUtils
 *
 *     @notice Utility library to apply a slippage percentage to an input amount
 */
library PercentageUtils {
    /**
     * @notice Adds the percentage to the given amount and returns the result
     *
     * @return The amount after the percentage is applied
     *
     * @dev It performs the following operation:
     *      (100.0 + percentage) * amount
     */
    function addPercentage(uint256 amount, Percentage percentage) internal pure returns (uint256) {
        return applyPercentage(amount, PERCENTAGE_100 + percentage);
    }

    /**
     * @notice Substracts the percentage from the given amount and returns the result
     *
     * @return The amount after the percentage is applied
     *
     * @dev It performs the following operation:
     *       (100.0 - percentage) * amount
     */
    function subtractPercentage(uint256 amount, Percentage percentage) internal pure returns (uint256) {
        return applyPercentage(amount, PERCENTAGE_100 - percentage);
    }

    /**
     * @notice Applies the given percentage to the given amount and returns the result
     *
     * @param amount The amount to apply the percentage to
     * @param percentage The percentage to apply to the amount
     *
     * @return The amount after the percentage is applied
     */
    function applyPercentage(uint256 amount, Percentage percentage) internal pure returns (uint256) {
        return (amount * Percentage.unwrap(percentage)) / Percentage.unwrap(PERCENTAGE_100);
    }

    /**
     * @notice Checks if the given percentage is in range, this is, if it is between 0 and 100
     *
     * @param percentage The percentage to check
     *
     * @return True if the percentage is in range, false otherwise
     */
    function isPercentageInRange(Percentage percentage) internal pure returns (bool) {
        return percentage <= PERCENTAGE_100;
    }

    /**
     * @notice Converts the given fraction into a percentage with the right number of decimals
     *
     * @param numerator The numerator of the fraction
     * @param denominator The denominator of the fraction
     *
     * @return The percentage with `PERCENTAGE_DECIMALS` decimals
     */
    function fromFraction(uint256 numerator, uint256 denominator) internal pure returns (Percentage) {
        return Percentage.wrap((numerator * PERCENTAGE_FACTOR) / denominator);
    }

    /**
     * @notice Converts the given decimal number into a percentage with the right number of decimals
     *
     * @param percentage The percentage in human-readable format, i.e., 50 for 50%
     *
     * @return The percentage with `PERCENTAGE_DECIMALS` decimals
     */
    function fromDecimalPercentage(uint256 percentage) internal pure returns (Percentage) {
        return Percentage.wrap(percentage * PERCENTAGE_FACTOR);
    }
}
