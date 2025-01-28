// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title Dutch Auction Errors
 * @notice This contract defines custom errors for the Dutch Auction system
 */
contract DutchAuctionErrors {
    /**
     * @notice Thrown when the auction duration is set to zero
     * @dev The auction duration must be greater than zero
     */
    error InvalidDuration();

    /**
     * @notice Thrown when the start price is not greater than the end price
     * @dev The start price must be strictly greater than the end price
     */
    error InvalidPrices();

    /**
     * @notice Thrown when the total number of tokens for auction is zero
     * @dev The total token amount must be greater than zero
     */
    error InvalidTokenAmount();

    /**
     * @notice Thrown when the kicker reward percentage is greater than 100%
     * @dev The kicker reward percentage must be between 0 and 100 inclusive
     */
    error InvalidKickerRewardPercentage();

    /**
     * @notice Thrown when trying to buy tokens outside the active auction period
     * @dev This can occur if trying to buy after the auction has ended
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionNotActive(uint256 auctionId);

    /**
     * @notice Thrown when trying to buy more tokens than are available in the auction
     * @dev The requested purchase amount must not exceed the remaining tokens
     */
    error InsufficientTokensAvailable();

    /**
     * @notice Thrown when trying to finalize an auction before its end time
     * @dev The auction can only be finalized after its scheduled end time
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionNotEnded(uint256 auctionId);

    /**
     * @notice Thrown when trying to interact with an auction that has already been finalized
     * @dev Once an auction is finalized, no further interactions should be possible
     * @dev auction is finalized when either the end time is reached or all tokens are sold
     * @param auctionId The ID of the auction being interacted with
     */
    error AuctionAlreadyFinalized(uint256 auctionId);

    /**
     * @notice Thrown when the auction token is invalid
     */
    error InvalidAuctionToken();

    /**
     * @notice Thrown when the payment token is invalid
     */
    error InvalidPaymentToken();

    /**
     * @notice Thrown when the auction has not been found
     */
    error AuctionNotFound();
}
