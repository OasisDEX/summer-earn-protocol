// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {BaseAuctionParameters} from "../types/CommonAuctionTypes.sol";

/**
 * @title IBuyAndBurnEvents
 * @notice Interface for events emitted by the BuyAndBurn contract
 * @dev This interface defines the events that are emitted during the BuyAndBurn process
 */
interface IBuyAndBurnEvents {
    /**
     * @notice Emitted when a new BuyAndBurn auction is started
     * @param auctionId The unique identifier of the auction
     * @param tokenToAuction The address of the token being auctioned
     * @param amount The total amount of tokens being put up for auction
     */
    event BuyAndBurnAuctionStarted(
        uint256 indexed auctionId,
        address indexed tokenToAuction,
        uint256 amount
    );

    /**
     * @notice Emitted when SUMMER tokens are burned as part of the BuyAndBurn process
     * @param amount The amount of SUMMER tokens that were burned
     */
    event SummerBurned(uint256 amount);

    /**
     * @notice Emitted when custom auction parameters are set for a token
     * @param token The address of the token for which the parameters were set
     * @param parameters The custom auction parameters
     */
    event TokenAuctionParametersSet(
        address indexed token,
        BaseAuctionParameters parameters
    );
}
