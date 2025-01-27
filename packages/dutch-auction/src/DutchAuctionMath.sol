// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {TokenLibrary} from "./lib/TokenLibrary.sol";
import {UD60x18, convert, ud, unwrap} from "@prb/math/src/UD60x18.sol";

/**
 * @title Dutch Auction Math Library
 * @author halaprix
 * @notice This library provides mathematical functions for Dutch auction calculations with support for various token
 * decimals
 * @dev Uses PRBMath library for precise calculations with fixed-point numbers and TokenLibrary for decimal conversions
 */
library DutchAuctionMath {
    using TokenLibrary for uint256;

    /**
     * @notice Calculates the current price based on linear decay
     * @dev The price decreases linearly from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param priceDecimals The number of decimals for the price values
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on linear decay
     *
     * @dev Process:
     * 1. Convert start and end prices to 18 decimals for precise calculation
     * 2. Calculate the price difference and decay amount using 18 decimal precision
     * 3. Subtract the decay amount from the start price
     * 4. Convert the result back to the desired number of decimals
     */
    function linearDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 priceDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 startPriceWei = startPrice.toWei(priceDecimals);
        uint256 endPriceWei = endPrice.toWei(priceDecimals);

        UD60x18 priceDifference = ud(startPriceWei - endPriceWei);
        UD60x18 timeElapsedUD = convert(timeElapsed);
        UD60x18 totalDurationUD = convert(totalDuration);

        UD60x18 decayedDifference = priceDifference.mul(timeElapsedUD).div(
            totalDurationUD
        );

        uint256 currentPriceWei = startPriceWei - unwrap(decayedDifference);
        return currentPriceWei.fromWei(resultDecimals);
    }

    /**
     * @notice Calculates the current price based on quadratic decay
     * @dev The price decreases quadratically from startPrice to endPrice over the duration
     * @param startPrice The starting price of the auction
     * @param endPrice The ending price of the auction
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param priceDecimals The number of decimals for the price values
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on quadratic decay
     *
     * @dev Process:
     * 1. Convert start and end prices to 18 decimals for precise calculation
     * 2. Calculate the remaining time and its square
     * 3. Calculate the decay amount using the formula: priceDifference * (remainingTime^2 / totalDuration^2)
     * 4. Add the decay amount to the end price
     * 5. Convert the result back to the desired number of decimals
     */
    function quadraticDecay(
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 priceDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 startPriceWei = startPrice.toWei(priceDecimals);
        uint256 endPriceWei = endPrice.toWei(priceDecimals);

        UD60x18 priceDifference = ud(startPriceWei - endPriceWei);
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

        uint256 currentPriceWei = endPriceWei + unwrap(decayedDifference);
        return currentPriceWei.fromWei(resultDecimals);
    }

    /**
     * @notice Calculates the total cost for a given price and amount, considering different token decimals
     * @dev Converts values to 18 decimals using TokenLibrary, performs the calculation, and converts the result back
     * @param price The price per unit
     * @param amount The number of units
     * @param priceDecimals The number of decimals for the price token
     * @param amountDecimals The number of decimals for the amount token
     * @param resultDecimals The desired number of decimals for the result
     * @return The total cost
     *
     * @dev Process:
     * 1. Convert both price and amount to 18 decimals for precise calculation
     * 2. Multiply the converted price and amount using PRBMath's high-precision operations
     * 3. Convert the result back to the desired number of decimals
     *
     * @dev Note: This function ensures high precision by performing all intermediate calculations
     * with 18 decimal places, regardless of the input or output decimal specifications.
     */
    function calculateTotalCost(
        uint256 price,
        uint256 amount,
        uint8 priceDecimals,
        uint8 amountDecimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        uint256 priceWei = price.toWei(priceDecimals);
        uint256 amountWei = amount.toWei(amountDecimals);

        UD60x18 resultUD = ud(priceWei).mul(ud(amountWei));

        return unwrap(resultUD).fromWei(resultDecimals);
    }
}
