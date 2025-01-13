// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

import {IAuctionManagerBaseEvents} from "../events/IAuctionManagerBaseEvents.sol";
import {BaseAuctionParameters} from "../types/CommonAuctionTypes.sol";

/**
 * @title AuctionManagerBase
 * @notice Base contract for managing Dutch auctions
 * @dev This abstract contract provides core functionality for creating and managing Dutch auctions
 */
abstract contract AuctionManagerBase is IAuctionManagerBaseEvents {
    using SafeERC20 for IERC20;
    using DutchAuctionLibrary for DutchAuctionLibrary.Auction;

    /// @notice Counter for tracking the current auction ID
    /// @dev Initialized to 0. Incremented before each new auction creation
    uint256 public currentAuctionId;

    /**
     * @notice Initializes the AuctionManagerBase
     */
    constructor() {
        // currentAuctionId is implicitly initialized to 0
    }

    /**
     * @dev Creates a new Dutch auction
     * @param auctionToken The token being auctioned
     * @param paymentToken The token used for payments
     * @param totalTokens The total number of tokens to be auctioned
     * @param unsoldTokensRecipient The address to receive any unsold tokens after the auction
     * @param baseParams The parameters for the auction
     * @return A new Auction struct
     * @custom:internal-logic
     * - Pre-increments currentAuctionId to generate a unique ID (first auction will have ID 1)
     * - Creates an AuctionParams struct using provided parameters
     * - Calls the createAuction function of the DutchAuctionLibrary to initialize the auction
     * @custom:effects
     * - Increments currentAuctionId
     * - Creates and returns a new Auction struct
     * @custom:security-considerations
     * - Ensure that the provided token addresses are valid
     * - Verify that totalTokens is non-zero and matches the actual token balance
     */
    function _createAuctionWithParams(
        IERC20 auctionToken,
        IERC20 paymentToken,
        uint256 totalTokens,
        address unsoldTokensRecipient,
        BaseAuctionParameters memory baseParams
    ) internal returns (DutchAuctionLibrary.Auction memory) {
        DutchAuctionLibrary.AuctionParams memory params = DutchAuctionLibrary
            .AuctionParams({
                auctionId: ++currentAuctionId,
                auctionToken: auctionToken,
                paymentToken: paymentToken,
                duration: baseParams.duration,
                startPrice: baseParams.startPrice,
                endPrice: baseParams.endPrice,
                totalTokens: totalTokens,
                kickerRewardPercentage: baseParams.kickerRewardPercentage,
                kicker: msg.sender,
                unsoldTokensRecipient: unsoldTokensRecipient,
                decayType: baseParams.decayType
            });

        return DutchAuctionLibrary.createAuction(params);
    }

    /**
     * @dev Gets the current price of an ongoing auction
     * @param auction The storage pointer to the auction
     * @return The current price of the auction in payment token decimals
     * @custom:internal-logic
     * - Calls the getCurrentPrice function of the DutchAuctionLibrary
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the auction is ongoing when calling this function
     */
    function _getCurrentPrice(
        DutchAuctionLibrary.Auction storage auction
    ) internal view returns (uint256) {
        return auction.getCurrentPrice();
    }
}
