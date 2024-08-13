// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

error AuctionAlreadyRunning(address tokenToAuction);
error NoTokensToAuction();
error AuctionNotEnded(uint256 auctionId);
error AuctionNotFound(uint256 auctionId);
