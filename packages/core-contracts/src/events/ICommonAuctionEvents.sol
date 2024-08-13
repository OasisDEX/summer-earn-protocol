// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../types/CommonAuctionTypes.sol";

interface ICommonAuctionEvents {
    event AuctionStarted(
        uint256 indexed auctionId,
        address indexed tokenToAuction,
        uint256 amount
    );

    event TokensPurchased(
        uint256 indexed auctionId,
        address indexed buyer,
        uint256 amount,
        uint256 summerAmount
    );

    event AuctionFinalized(
        uint256 indexed auctionId,
        uint256 soldTokens,
        uint256 burnedSummer,
        uint256 unsoldTokens
    );

    event AuctionDefaultParametersUpdated(
        AuctionDefaultParameters newParameters
    );
}
