// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {DecayFunctions} from "@summerfi/dutch-auction/DecayFunctions.sol";
import {Percentage} from "@summerfi/percentage-solidity/contracts/Percentage.sol";

/**
 * @title BaseAuctionParameters
 * @notice Struct containing default parameters for Dutch auctions
 * @dev This struct is used to configure the default settings for Dutch auctions in the protocol
 */
struct BaseAuctionParameters {
    /**
     * @notice The duration of the auction in seconds
     * @dev This value determines how long the auction will run before it can be finalized
     */
    uint40 duration;
    /**
     * @notice The starting price of the auction in payment token decimals
     * @dev This is the highest price at which the auction begins
     */
    uint256 startPrice;
    /**
     * @notice The ending price of the auction in payment token decimals
     * @dev This is the lowest price the auction can reach. The auction ends when this price is hit or when duration is
     * reached
     */
    uint256 endPrice;
    /**
     * @notice The percentage of auctioned tokens to be given as a reward to the auction initiator (kicker)
     * @dev This is represented as a Percentage type, where 100 * 1e18 = 100%
     * @dev This value is used to incentivize the auction initiator to kick off the auction
     * @dev The reward is calculated as a percentage of the total auctioned tokens
     */
    Percentage kickerRewardPercentage;
    /**
     * @notice The type of price decay function to use for the auction
     * @dev This determines how the price changes over time during the auction
     * @dev See DecayFunctions.sol for more information
     */
    DecayFunctions.DecayType decayType;
}
