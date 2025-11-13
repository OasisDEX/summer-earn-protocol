// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage, PERCENTAGE_FACTOR} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Bps, toPercentage, fromPercentage, toBps, BPS_PER_PERCENTAGE} from "./Bps.sol";

/**
 * @title BpsUtils
 * @author James Tuckett
 * @author Roberto Cano
 * @notice Utility library for working with basis points (BPS) calculations
 * @dev Provides functions to convert between BPS and Percentage types, and perform BPS-based calculations
 */
library BpsUtils {
    using PercentageUtils for uint256;

    /**
     * @notice Adds basis points to an amount (amount * (100% + bps))
     * @param amount The base amount
     * @param bps The basis points to add (e.g., 100 = 1% increase)
     * @return The amount with the basis points added
     */
    function addBps(uint256 amount, Bps bps) internal pure returns (uint256) {
        Percentage percentage = toPercentage(bps);

        return PercentageUtils.addPercentage(amount, percentage);
    }

    /**
     * @notice Applies a basis points discount to an amount
     * @param amount The base amount
     * @param discountBps The discount in basis points (e.g., 50 = 0.5% discount)
     * @return discountedAmount The amount after applying the discount
     */
    function subtractBps(
        uint256 amount,
        Bps discountBps
    ) internal pure returns (uint256) {
        Percentage discount = toPercentage(discountBps);
        return PercentageUtils.subtractPercentage(amount, discount);
    }

    /**
     * @notice Applies a basis points fee to an amount
     * @param amount The base amount
     * @param feeBps The fee in basis points (e.g., 50 = 0.5% fee)
     * @return feeAmount The fee amount
     */
    function applyBps(
        uint256 amount,
        Bps feeBps
    ) internal pure returns (uint256) {
        Percentage fee = toPercentage(feeBps);
        return PercentageUtils.applyPercentage(amount, fee);
    }

    /**
     * @notice Converts the given integer into a BPS
     * @param bps The BPS in human-readable format, i.e., 50 for 50%
     * @return The BPS representation of the value
     * @dev This function is useful for converting human-readable BPSs to the internal representation
     */
    function fromIntegerBPS(uint256 bps) internal pure returns (Bps) {
        // No need to divide by the BPS_PER_PERCENTAGE here because
        // we are just interested in having the same scaling as Percentage (10^18)
        return
            toBps(
                Percentage.unwrap(PercentageUtils.fromIntegerPercentage(bps))
            );
    }
}
