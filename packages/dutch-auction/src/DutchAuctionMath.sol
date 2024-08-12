// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {UD60x18, convert, ud, unwrap} from "@prb/math/src/UD60x18.sol";

/**
 * @title Dutch Auction Math Library
 * @author halaprix
 * @notice This library provides mathematical functions for Dutch auction calculations
 * @dev Uses PRBMath library for precise calculations with fixed-point numbers
 */
library DutchAuctionMath {
    /**
     * @notice Calculates the current price based on linear decay
     * @dev The price decreases linearly from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @return The current price based on linear decay
     */
    function linearDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration
    ) internal pure returns (uint256) {
        if (timeElapsed >= totalDuration) {
            return endPrice;
        }
        uint256 priceDifference = startPrice - endPrice;
        uint256 decay = (priceDifference * timeElapsed) / totalDuration;
        return startPrice - decay;
    }

    /**
     * @notice Calculates the current price based on exponential decay
     * @dev The price decreases exponentially from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @return The current price based on exponential decay
     */
    function exponentialDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration
    ) internal pure returns (uint256) {
        if (timeElapsed >= totalDuration) {
            return endPrice;
        }
        UD60x18 priceDifference = ud(startPrice - endPrice);
        UD60x18 timeRemaining = convert(totalDuration - timeElapsed);
        UD60x18 totalDurationUD = convert(totalDuration);

        // Calculate (totalDuration - timeElapsed) ** 2
        UD60x18 timeRemainingSquared = timeRemaining.powu(2);

        // Calculate totalDuration ** 2
        UD60x18 totalDurationSquared = totalDurationUD.powu(2);

        // Calculate (priceDifference * (totalDuration - timeElapsed) ** 2) / totalDuration ** 2
        UD60x18 decayedDifference = priceDifference
            .mul(timeRemainingSquared)
            .div(totalDurationSquared);
        return endPrice + unwrap(decayedDifference);
    }

    /**
     * @notice Calculates the total cost for a given price and amount
     * @dev Multiplies the price by the amount, using fixed-point arithmetic for precision
     * @param price The price per unit
     * @param amount The number of units
     * @return The total cost
     */
    function calculateTotalCost(
        uint256 price,
        uint256 amount
    ) internal pure returns (uint256) {
        return unwrap(ud(price).mul(ud(amount)));
    }
}
