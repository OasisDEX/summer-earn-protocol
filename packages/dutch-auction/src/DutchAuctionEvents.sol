// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

contract DutchAuctionEvents {
    /**
     * @dev Emitted when a new auction is created
     * @param auctionId The unique identifier of the created auction
     * @param auctionKicker The address of the account that initiated the auction
     * @param totalTokens The total number of tokens being auctioned
     * @param kickerRewardAmount The number of tokens reserved as a reward for the auction kicker
     */
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed auctionKicker,
        uint256 totalTokens,
        uint256 kickerRewardAmount
    );

    /**
     * @dev Emitted when tokens are purchased in an auction
     * @param auctionId The unique identifier of the auction
     * @param buyer The address of the account that purchased the tokens
     * @param amount The number of tokens purchased
     * @param price The price per token at the time of purchase
     */
    event TokensPurchased(
        uint256 indexed auctionId,
        address indexed buyer,
        uint256 amount,
        uint256 price
    );

    /**
     * @dev Emitted when an auction is finalized
     * @param auctionId The unique identifier of the finalized auction
     * @param soldTokens The total number of tokens sold in the auction
     * @param unsoldTokens The number of tokens that remained unsold
     */
    event AuctionFinalized(
        uint256 indexed auctionId,
        uint256 soldTokens,
        uint256 unsoldTokens
    );

    /**
     *
     * @param auctionId The unique identifier of the auction
     * @param kicker The address of the account that initiated the auction
     * @param amount The number of tokens claimed as a reward
     */
    event KickerRewardClaimed(
        uint256 indexed auctionId,
        address indexed kicker,
        uint256 amount
    );
}
