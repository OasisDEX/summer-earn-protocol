// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../types/RaftTypes.sol";

interface IRaftEvents {
    event AuctionConfigUpdated(AuctionConfig newConfig);
    event ArkRewardTokenAuctionStarted(
        uint256 auctionId,
        address ark,
        address rewardToken,
        uint256 amount
    );
    event ArkHarvested(address indexed ark, address indexed rewardToken);
    event RewardBoarded(
        address indexed ark,
        address indexed fromRewardToken,
        address indexed toFleetToken,
        uint256 amountReboarded
    );
}
