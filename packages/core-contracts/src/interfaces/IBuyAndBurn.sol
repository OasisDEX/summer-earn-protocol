// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IBuyAndBurnEvents} from "../events/IBuyAndBurnEvents.sol";
import {IBuyAndBurnErrors} from "../errors/IBuyAndBurnErrors.sol";
import {AuctionDefaultParameters} from "../types/CommonAuctionTypes.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/src/DutchAuctionLibrary.sol";

/**
 * @title IBuyAndBurn
 * @notice Interface for the BuyAndBurn contract, which manages token auctions and burns SUMMER tokens
 */
interface IBuyAndBurn is IBuyAndBurnEvents, IBuyAndBurnErrors {
    /**
     * @notice Starts a new auction for a specified token
     * @param tokenToAuction The address of the token to be auctioned
     * @dev Only callable by the governor
     * @dev Emits a BuyAndBurnAuctionStarted event
     */
    function startAuction(address tokenToAuction) external;

    /**
     * @notice Allows users to buy tokens from an ongoing auction
     * @param auctionId The ID of the auction
     * @param amount The amount of tokens to buy
     * @return summerAmount The amount of SUMMER tokens required to purchase the specified amount of auction tokens
     * @dev Emits a TokensPurchased event
     */
    function buyTokens(
        uint256 auctionId,
        uint256 amount
    ) external returns (uint256 summerAmount);

    /**
     * @notice Finalizes an auction after its end time
     * @param auctionId The ID of the auction to finalize
     * @dev Only callable by the governor
     * @dev Emits a SummerBurned event
     */
    function finalizeAuction(uint256 auctionId) external;

    /**
     * @notice Retrieves information about a specific auction
     * @param auctionId The ID of the auction
     * @return auction The Auction struct containing auction details
     */
    function getAuctionInfo(
        uint256 auctionId
    ) external view returns (DutchAuctionLibrary.Auction memory auction);

    /**
     * @notice Gets the current price of tokens in an ongoing auction
     * @param auctionId The ID of the auction
     * @return The current price of tokens in the auction
     */
    function getCurrentPrice(uint256 auctionId) external view returns (uint256);

    /**
     * @notice Updates the default parameters for future auctions
     * @param newParameters The new default parameters
     * @dev Only callable by the governor
     * @dev Emits an AuctionDefaultParametersUpdated event
     */
    function updateAuctionDefaultParameters(
        AuctionDefaultParameters calldata newParameters
    ) external;

    /**
     * @notice Sets a new treasury address
     * @param newTreasury The address of the new treasury
     * @dev Only callable by the governor
     */
    function setTreasury(address newTreasury) external;
}
