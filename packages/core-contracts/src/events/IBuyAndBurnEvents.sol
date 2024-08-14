// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../types/CommonAuctionTypes.sol";

interface IBuyAndBurnEvents {
    event BuyAndBurnAuctionStarted(
        uint256 indexed auctionId,
        address indexed tokenToAuction,
        uint256 amount
    );
    event SummerBurned(uint256 amount);
}
