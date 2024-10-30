// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

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
}
