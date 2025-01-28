// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBuyAndBurnErrors} from "../errors/IBuyAndBurnErrors.sol";
import {IBuyAndBurnEvents} from "../events/IBuyAndBurnEvents.sol";
import {BaseAuctionParameters} from "../types/CommonAuctionTypes.sol";
import {DutchAuctionLibrary} from "@summerfi/dutch-auction/DutchAuctionLibrary.sol";

/**
 * @title IBuyAndBurn
 * @notice Interface for the BuyAndBurn contract, which manages token auctions and burns SUMMER tokens
 */
interface IBuyAndBurn is IBuyAndBurnEvents, IBuyAndBurnErrors {
    /**
     * @dev Starts a new auction for a specified token
     * @param tokenToAuction The address of the token to be auctioned
     * @custom:override Implements the startAuction function from IBuyAndBurn
     * @custom:internal-logic
     * - Checks if there's already an ongoing auction for the token
     * - Creates a new auction using the current balance of the token
     * - Stores the auction data and updates the ongoingAuctions mapping
     * @custom:effects
     * - Creates a new auction
     * - Updates the ongoingAuctions mapping
     * - Emits a BuyAndBurnAuctionStarted event
     * @custom:security-considerations
     * - Only callable by the governor
     * - Ensure the contract has the necessary token balance before starting the auction
     */
    function startAuction(address tokenToAuction) external;

    /**
     * @dev Allows users to buy tokens from an ongoing auction
     * @param auctionId The ID of the auction
     * @param amount The amount of tokens to buy
     * @return summerAmount The amount of SUMMER tokens required to purchase the specified amount of auction tokens
     * @custom:override Implements the buyTokens function from IBuyAndBurn
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the buyTokens function of the DutchAuctionLibrary
     * - Updates the amount of SUMMER raised in the auction
     * - Settles the auction if all tokens are sold
     * @custom:effects
     * - Transfers tokens between the buyer and the contract
     * - Updates the auction state
     * - May settle the auction if all tokens are sold
     * @custom:security-considerations
     * - Ensure proper token transfers and balance updates
     * - Handle potential reentrancy risks
     */
    function buyTokens(
        uint256 auctionId,
        uint256 amount
    ) external returns (uint256 summerAmount);

    /**
     * @dev Finalizes an auction after its end time
     * @param auctionId The ID of the auction to finalize
     * @custom:override Implements the finalizeAuction function from IBuyAndBurn
     * @custom:internal-logic
     * - Retrieves the auction data
     * - Calls the finalizeAuction function of the DutchAuctionLibrary
     * - Settles the auction
     * - if all tokens are sold, the auction is settled automatically
     * @custom:effects
     * - Updates the auction state
     * - Burns SUMMER tokens
     * - Cleans up auction-related state
     * @custom:security-considerations
     * - Ensure proper handling of remaining tokens and raised funds
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
     * @notice Sets auction parameters for a specific token
     * @param token The token address
     * @param parameters The auction parameters
     */
    function setTokenAuctionParameters(
        address token,
        BaseAuctionParameters calldata parameters
    ) external;
}
