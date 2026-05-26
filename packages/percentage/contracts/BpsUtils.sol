// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BPS, BPS_100, BPS_FACTOR} from "./BPS.sol";

/**
 * @title BpsUtils
 * @author Roberto Cano
 * @notice Utility library to apply basis-point calculations to input amounts
 * @dev Mirrors the API of PercentageUtils, replacing the high-precision
 *      PERCENTAGE_FACTOR with the standard BPS_FACTOR (10000).
 */
library BpsUtils {
    /**
     * @notice Increases `amount` by `bps` basis points
     * @dev Computes (BPS_100 + bps) * amount / BPS_FACTOR
     *      e.g. addBps(1000, BPS.wrap(100)) returns 1010 (1% increase)
     * @param amount The base amount
     * @param bps The basis points to add (must not exceed BPS_100)
     * @return The amount after the increase
     */
    function addBps(
        uint256 amount,
        BPS bps
    ) internal pure returns (uint256) {
        return applyBps(amount, BPS_100 + bps);
    }

    /**
     * @notice Decreases `amount` by `bps` basis points
     * @dev Computes (BPS_100 - bps) * amount / BPS_FACTOR
     *      e.g. subtractBps(1000, BPS.wrap(100)) returns 990 (1% decrease)
     * @param amount The base amount
     * @param bps The basis points to subtract (must not exceed BPS_100)
     * @return The amount after the decrease
     */
    function subtractBps(
        uint256 amount,
        BPS bps
    ) internal pure returns (uint256) {
        return applyBps(amount, BPS_100 - bps);
    }

    /**
     * @notice Applies `bps` directly to `amount`
     * @dev Computes bps * amount / BPS_FACTOR
     *      e.g. applyBps(1000, BPS.wrap(500)) returns 50 (5% of 1000)
     * @param amount The base amount
     * @param bps The basis points to apply
     * @return The portion of amount represented by bps
     */
    function applyBps(
        uint256 amount,
        BPS bps
    ) internal pure returns (uint256) {
        return (amount * BPS.unwrap(bps)) / BPS_FACTOR;
    }

    /**
     * @notice Returns true if `bps` is a valid basis-point value (0 – 10000)
     * @param bps The value to check
     */
    function isBpsInRange(BPS bps) internal pure returns (bool) {
        return bps <= BPS_100;
    }

    /**
     * @notice Converts the fraction `numerator / denominator` into a BPS value
     * @dev e.g. fromFraction(1, 4) returns BPS.wrap(2500) (25%)
     * @param numerator The numerator of the fraction
     * @param denominator The denominator of the fraction
     * @return The equivalent BPS value
     */
    function fromFraction(
        uint256 numerator,
        uint256 denominator
    ) internal pure returns (BPS) {
        return BPS.wrap((numerator * BPS_FACTOR) / denominator);
    }
}
