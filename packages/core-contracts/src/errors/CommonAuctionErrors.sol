// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

/**
 * @notice Thrown when trying to start an auction with no tokens available to auction
 */
error NoTokensToAuction();
/**
 * @notice Thrown when trying to start an auction with no tokens available to auction
 */
error AuctionNotEnded(uint256 auctionId);
/**
 * @notice Thrown when trying to start an auction with no tokens available to auction
 */
error AuctionNotFound(uint256 auctionId);
