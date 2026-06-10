// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IStakingRewards
 * @notice Interface for a Synthetix-style staking rewards distributor (as used by Sky)
 */
interface IStakingRewards {
    // Views

    /// @notice Returns the staked balance of an account
    /// @param account The account to query
    /// @return The staked balance
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the rewards earned but not yet claimed by an account
    /// @param account The account to query
    /// @return The earned reward amount
    function earned(address account) external view returns (uint256);

    /// @notice Returns the total rewards distributed over the current reward duration
    /// @return The reward amount for the current duration
    function getRewardForDuration() external view returns (uint256);

    /// @notice Returns the last timestamp at which rewards are applicable
    /// @return The applicable timestamp (min of now and period finish)
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Returns the accumulated reward per staked token
    /// @return The reward per token, scaled
    function rewardPerToken() external view returns (uint256);

    /// @notice Returns the address authorized to notify new reward amounts
    /// @return The rewards distribution address
    function rewardsDistribution() external view returns (address);

    /// @notice Returns the token distributed as rewards
    /// @return The reward token
    function rewardsToken() external view returns (IERC20);

    /// @notice Returns the token that is staked
    /// @return The staking token
    function stakingToken() external view returns (IERC20);

    /// @notice Returns the total amount of staked tokens
    /// @return The total staked supply
    function totalSupply() external view returns (uint256);

    // Mutative

    /// @notice Withdraws the caller's entire staked balance and claims rewards
    function exit() external;

    /// @notice Claims the caller's accrued rewards
    function getReward() external;

    /// @notice Stakes `amount` of the staking token for the caller
    /// @param amount The amount to stake
    function stake(uint256 amount) external;

    /// @notice Stakes `amount` of the staking token for the caller with a referral code
    /// @param amount The amount to stake
    /// @param referral A referral code for tracking
    function stake(uint256 amount, uint16 referral) external;

    /// @notice Withdraws `amount` of staked tokens for the caller
    /// @param amount The amount to withdraw
    function withdraw(uint256 amount) external;

    /// @notice Notifies the contract of a new reward amount to distribute over the reward duration
    /// @param reward The reward amount being added
    function notifyRewardAmount(uint256 reward) external;

    /// @notice Sets the address authorized to notify reward amounts
    /// @param _rewardsDistribution The new rewards distribution address
    function setRewardsDistribution(address _rewardsDistribution) external;

    /// @notice Sets the duration over which rewards are distributed
    /// @param _rewardsDuration The new reward duration in seconds
    function setRewardsDuration(uint256 _rewardsDuration) external;

    /// @notice Recovers ERC20 tokens accidentally sent to the contract (excluding staking token)
    /// @param tokenAddress The token to recover
    /// @param tokenAmount The amount to recover
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
