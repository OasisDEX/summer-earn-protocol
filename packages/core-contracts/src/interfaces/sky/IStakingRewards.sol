// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStakingRewards {
    // Views

    function balanceOf(address account) external view returns (uint256);

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function rewardsDistribution() external view returns (address);

    function rewardsToken() external view returns (IERC20);

    function stakingToken() external view returns (IERC20);

    function totalSupply() external view returns (uint256);

    // Mutative

    function exit() external;

    function getReward() external;

    function stake(uint256 amount) external;

    function stake(uint256 amount, uint16 referral) external;

    function withdraw(uint256 amount) external;

    function notifyRewardAmount(uint256 reward) external;

    function setRewardsDistribution(address _rewardsDistribution) external;

    function setRewardsDuration(uint256 _rewardsDuration) external;

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
