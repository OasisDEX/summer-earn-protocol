// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

error RewardsSwapFailed(address caller);
error ReceivedLess(uint256 receiveAtLeast, uint256 balance);
error SwapAmountMustMatchHarvestedAmount(
    uint256 swapAmount,
    uint256 harvestedAmount,
    address rewardToken
);
