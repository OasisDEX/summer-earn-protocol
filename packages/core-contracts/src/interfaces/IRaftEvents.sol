// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

interface IRaftEvents {
    event ArkHarvested(address indexed ark, address indexed rewardToken);
    event RewardSwapped(
        address indexed rewardIn,
        address indexed fleetTokenOut,
        uint256 amountIn,
        uint256 amountReceived
    );
    event RewardReboarded(
        address indexed ark,
        address indexed rewardToken,
        uint256 originalRewardBalance,
        uint256 amountReinvested
    );
}
