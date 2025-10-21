// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Percentage, PERCENTAGE_FACTOR} from "@summerfi/percentage-solidity/contracts/Percentage.sol";
import {PercentageUtils} from "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";
import {Bps, BPS_FACTOR, toBps, fromBps} from "./Bps.sol";

/**
 * @title BpsUtils
 * @notice Utility library for working with basis points (BPS) calculations
 * @dev Provides functions to convert between BPS and Percentage types, and perform BPS-based calculations
 */
library BpsUtils {
    using PercentageUtils for uint256;

    /**
     * @notice Converts basis points to Percentage type
     * @param bps Basis points value (e.g., 50 = 0.5%)
     * @return percentage The equivalent Percentage value
     */
    function bpsToPercentage(Bps bps) internal pure returns (Percentage) {
        // Convert BPS to percentage with 18 decimals
        // Formula: (bps * PERCENTAGE_FACTOR) / BPS_FACTOR
        return Percentage.wrap((fromBps(bps) * PERCENTAGE_FACTOR) / BPS_FACTOR);
    }

    /**
     * @notice Converts Percentage type to basis points
     * @param percentage The Percentage value
     * @return bps The equivalent basis points value
     */
    function percentageToBps(
        Percentage percentage
    ) internal pure returns (Bps) {
        // Convert percentage to BPS
        // Formula: (percentage * BPS_FACTOR) / PERCENTAGE_FACTOR
        return
            toBps(
                (Percentage.unwrap(percentage) * BPS_FACTOR) / PERCENTAGE_FACTOR
            );
    }

    /**
     * @notice Applies a basis points discount to an amount
     * @param amount The base amount
     * @param discountBps The discount in basis points (e.g., 50 = 0.5% discount)
     * @return discountedAmount The amount after applying the discount
     */
    function applyBpsDiscount(
        uint256 amount,
        Bps discountBps
    ) internal pure returns (uint256) {
        Percentage discount = bpsToPercentage(discountBps);
        return PercentageUtils.subtractPercentage(amount, discount);
    }

    /**
     * @notice Applies a basis points fee to an amount
     * @param amount The base amount
     * @param feeBps The fee in basis points (e.g., 50 = 0.5% fee)
     * @return feeAmount The fee amount
     */
    function calculateBpsFee(
        uint256 amount,
        Bps feeBps
    ) internal pure returns (uint256) {
        Percentage fee = bpsToPercentage(feeBps);
        return PercentageUtils.applyPercentage(amount, fee);
    }

    /**
     * @notice Validates that a basis points value is within valid range
     * @param bps The basis points value to validate
     * @return valid True if the value is between 0 and 10000 (0% to 100%)
     */
    function isValidBps(Bps bps) internal pure returns (bool) {
        return fromBps(bps) <= BPS_FACTOR;
    }
}
