// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./DutchAuctionMath.sol";

/**
 * @title DecayFunctions Library
 * @author halaprix
 * @notice This library provides functions to calculate price decay for Dutch auctions
 * @dev Implements both linear and quadratic decay functions
 */
library DecayFunctions {
    /**
     * @notice Enum representing the types of decay functions available
     * @dev Used to select between linear and quadratic decay in calculations
     */
    enum DecayType {
        Linear,
        Quadratic
    }

    /**
     * @notice Thrown when the decay type is invalid
     */
    error InvalidDecayType();

    /**
     * @notice Calculates the current price based on the specified decay type
     * @dev This function acts as a wrapper for the specific decay calculations in DutchAuctionMath
     * @param decayType The type of decay function to use (Linear or Quadratic)
     * @param startPrice The starting price of the auction (in token units)
     * @param endPrice The ending price of the auction (in token units)
     * @param timeElapsed The time elapsed since the start of the auction
     * @param totalDuration The total duration of the auction
     * @param decimals The number of decimals for the input prices
     * @param resultDecimals The desired number of decimals for the result
     * @return The current price based on the specified decay function
     *
     * @dev Calculation process:
     * 1. Check if the auction has ended (timeElapsed >= totalDuration)
     * 2. If the auction has ended, return the end price
     * 3. If the auction is still active, calculate the current price using the specified decay function
     * 4. For Linear decay, use DutchAuctionMath.linearDecay
     * 5. For Quadratic decay, use DutchAuctionMath.quadraticDecay
     *
     * @dev Note on precision:
     * - All price calculations are performed with high precision using the DutchAuctionMath library
     * - The input prices and result can have different decimal places, allowing for flexible token configurations
     *
     * @dev Usage:
     * - This function should be called periodically to get the current price of the auctioned item
     * - It can handle different token decimals for both input and output, making it versatile for various token pairs
     */
    function calculateDecay(
        DecayType decayType,
        uint256 startPrice,
        uint256 endPrice,
        uint256 timeElapsed,
        uint256 totalDuration,
        uint8 decimals,
        uint8 resultDecimals
    ) internal pure returns (uint256) {
        // Check if the auction has ended
        if (timeElapsed >= totalDuration) {
            return endPrice;
        }

        // Calculate the current price based on the specified decay type
        if (decayType == DecayType.Linear) {
            return
                DutchAuctionMath.linearDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration,
                    decimals,
                    resultDecimals
                );
        } else if (decayType == DecayType.Quadratic) {
            return
                DutchAuctionMath.quadraticDecay(
                    startPrice,
                    endPrice,
                    timeElapsed,
                    totalDuration,
                    decimals,
                    resultDecimals
                );
        } else {
            revert InvalidDecayType();
        }
    }
}
