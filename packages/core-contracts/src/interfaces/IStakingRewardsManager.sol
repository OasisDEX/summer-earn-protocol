// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakingRewardsManagerErrors} from "../errors/IStakingRewardsManagerErrors.sol";

/* @title IStakingRewardsManager
 * @notice Interface for the Staking Rewards Manager contract
 * @dev Manages staking and distribution of multiple reward tokens
 */
interface IStakingRewardsManager is IStakingRewardsManagerErrors {
    /* @notice Parameters for initializing the Staking Rewards Manager */
    struct StakingRewardsParams {
        address[] rewardsTokens;
        address governor;
        address accessManager;
    }

    // Views

    /* @notice Get the total amount of staked tokens
     * @return The total supply of staked tokens
     */
    function totalSupply() external view returns (uint256);

    /* @notice Get the staked balance of a specific account
     * @param account The address of the account to check
     * @return The staked balance of the account
     */
    function balanceOf(address account) external view returns (uint256);

    /* @notice Get the last time the reward was applicable for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The timestamp of the last applicable reward time
     */
    function lastTimeRewardApplicable(
        IERC20 rewardToken
    ) external view returns (uint256);

    /* @notice Get the reward per token for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The reward amount per staked token
     */
    function rewardPerToken(IERC20 rewardToken) external view returns (uint256);

    /* @notice Calculate the earned reward for an account and a specific reward token
     * @param account The address of the account
     * @param rewardToken The address of the reward token
     * @return The amount of reward tokens earned
     */
    function earned(
        address account,
        IERC20 rewardToken
    ) external view returns (uint256);

    /* @notice Get the reward for the entire duration for a specific reward token
     * @param rewardToken The address of the reward token
     * @return The total reward amount for the duration
     */
    function getRewardForDuration(
        IERC20 rewardToken
    ) external view returns (uint256);

    /* @notice Get the address of the staking token
     * @return The IERC20 interface of the staking token
     */
    function stakingToken() external view returns (IERC20);

    /* @notice Get the reward token at a specific index
     * @param index The index of the reward token
     * @return The IERC20 interface of the reward token
     */
    function rewardsTokens(uint256 index) external view returns (IERC20);

    // Mutative functions

    /* @notice Stake tokens for an account
     * @param account The address of the account to stake for
     * @param amount The amount of tokens to stake
     */
    function stake(address account, uint256 amount) external;

    /* @notice Withdraw staked tokens
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external;

    /* @notice Claim accumulated rewards */
    function getReward() external;

    /* @notice Withdraw all staked tokens and claim rewards */
    function exit() external;

    // Admin functions

    /* @notice Notify the contract about new reward amount
     * @param rewardToken The address of the reward token
     * @param reward The amount of new reward
     */
    function notifyRewardAmount(IERC20 rewardToken, uint256 reward) external;

    /* @notice Set the duration for rewards distribution
     * @param rewardToken The address of the reward token
     * @param _rewardsDuration The new duration for rewards
     */
    function setRewardsDuration(
        IERC20 rewardToken,
        uint256 _rewardsDuration
    ) external;

    /* @notice Add a new reward token
     * @param rewardToken The address of the new reward token
     * @param rewardsDuration The duration for the new reward token
     */
    function addRewardToken(
        IERC20 rewardToken,
        uint256 rewardsDuration
    ) external;

    /* @notice Initialize the staking token
     * @param _stakingToken The address of the staking token
     */
    function initializeStakingToken(IERC20 _stakingToken) external;

    // Events

    /* @notice Emitted when a new reward is added
     * @param rewardToken The address of the reward token
     * @param reward The amount of reward added
     */
    event RewardAdded(address indexed rewardToken, uint256 reward);

    /* @notice Emitted when tokens are staked
     * @param account The address of the account that staked
     * @param amount The amount of tokens staked
     */
    event Staked(address indexed account, uint256 amount);

    /* @notice Emitted when tokens are withdrawn
     * @param user The address of the user that withdrew
     * @param amount The amount of tokens withdrawn
     */
    event Withdrawn(address indexed user, uint256 amount);

    /* @notice Emitted when rewards are paid out
     * @param user The address of the user receiving the reward
     * @param rewardToken The address of the reward token
     * @param reward The amount of reward paid
     */
    event RewardPaid(
        address indexed user,
        address indexed rewardToken,
        uint256 reward
    );

    /* @notice Emitted when the rewards duration is updated
     * @param rewardToken The address of the reward token
     * @param newDuration The new duration for rewards
     */
    event RewardsDurationUpdated(
        address indexed rewardToken,
        uint256 newDuration
    );

    /* @notice Emitted when a new reward token is added
     * @param rewardToken The address of the new reward token
     * @param rewardsDuration The duration for the new reward token
     */
    event RewardTokenAdded(address rewardToken, uint256 rewardsDuration);

    /* @notice Emitted when the staking token is initialized
     * @param stakingToken The address of the staking token
     */
    event StakingTokenInitialized(address stakingToken);
}
