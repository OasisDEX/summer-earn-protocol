// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import {IRewarder, IERC20} from "./IRewarder.sol";

/// @notice Per-pool reward accounting state shared between multiple libraries.
/// @dev This is an internal struct, placed here as its shared between multiple libraries.
struct RewardPool {
    uint256 accRewardPerShare;
    address rewardToken;
    uint48 lastRewardTime;
    uint48 allocPoints;
    IERC20 stakingToken;
    bool removed;
    mapping(address => uint256) rewardDebt;
}

/// @title IMultiRewarder
/// @notice A rewarder that can distribute multiple reward tokens (ERC20 and native) to `StargateStaking` pools.
/// @dev The native token is encoded as 0x0.
interface IMultiRewarder is IRewarder {
    /// @notice Emission configuration and schedule for a reward token
    struct RewardDetails {
        uint256 rewardPerSec;
        uint160 totalAllocPoints;
        uint48 start;
        uint48 end;
        bool exists;
    }

    /// @notice MultiRewarder renounce ownership is disabled.
    error MultiRewarderRenounceOwnershipDisabled();
    /// @notice The token is not connected to the staking contract, connect it first.
    error MultiRewarderDisconnectedStakingToken(address token);
    /// @notice This token is not registered via `setReward` yet, register it first.
    error MultiRewarderUnregisteredToken(address token);
    /**
     *  @notice Due to various functions looping over the staking tokens connected to a reward token,
     *          a maximum number of such links is instated.
     */
    error MultiRewarderMaxPoolsForRewardToken();
    /**
     *  @notice Due to various functions looping over the reward tokens connected to a staking token,
     *          a maximum number of such links is instated.
     */
    error MultiRewarderMaxActiveRewardTokens();
    /// @notice The function can only be called while the pool hasn't ended yet.
    error MultiRewarderPoolFinished(address rewardToken);
    /// @notice The pool emission duration cannot be set to zero, as this would cause the rewards to be voided.
    error MultiRewarderZeroDuration();
    /// @notice The pool start time cannot be set in the past, as this would cause the rewards to be voided.
    error MultiRewarderStartInPast(uint256 start);
    /**
     *  @notice The recipient failed to handle the receipt of the native tokens, do they have a receipt hook?
     *          If not, use `emergencyWithdraw`.
     */
    error MultiRewarderNativeTransferFailed(address to, uint256 amount);
    /**
     *  @notice A wrong `msg.value` was provided while setting a native reward, make sure it matches the function
     *          `amount`.
     */
    error MultiRewarderIncorrectNative(uint256 expected, uint256 actual);
    /**
     *  @notice Due to a zero input or rounding, the reward rate while setting this pool would be zero,
     *          which is not allowed.
     */
    error MultiRewarderZeroRewardRate();

    /// @notice Emitted when additional rewards were added to a pool, extending the reward duration.
    event RewardExtended(
        address indexed rewardToken,
        uint256 amountAdded,
        uint48 newEnd
    );
    /**
     *  @notice Emitted when a reward token has been registered. Can be emitted again for the same token after it has
     *          been explicitly stopped.
     */
    event RewardRegistered(address indexed rewardToken);
    /// @notice Emitted when the reward pool has been adjusted or intialized, with the new params.
    event RewardSet(
        address indexed rewardToken,
        uint256 amountAdded,
        uint256 amountPeriod,
        uint48 start,
        uint48 duration
    );
    /// @notice Emitted whenever rewards are claimed via the staking pool.
    event RewardsClaimed(
        address indexed user,
        address[] rewardTokens,
        uint256[] amounts
    );
    /**
     *  @notice Emitted whenever a new staking pool combination was registered via the allocation point adjustment
     *          function.
     */
    event PoolRegistered(
        address indexed rewardToken,
        IERC20 indexed stakeToken
    );
    /// @notice Emitted when the owner adjusts the allocation points for pools.
    event AllocPointsSet(
        address indexed rewardToken,
        IERC20[] indexed stakeToken,
        uint48[] allocPoint
    );
    /// @notice Emitted when a reward token is stopped.
    event RewardStopped(
        address indexed rewardToken,
        address indexed receiver,
        bool pullTokens
    );

    /**
     *  @notice Sets the reward for `rewards` of `rewardToken` over `duration` seconds, starting at `start`. The actual
     *          reward over this period will be increased by any rewards on the pool that haven't been distributed yet.
     *  @param  rewardToken The reward token to configure
     *  @param  rewards The total reward amount to distribute over the period
     *  @param  start The start time of the emission
     *  @param  duration The emission duration in seconds
     */
    function setReward(
        address rewardToken,
        uint256 rewards,
        uint48 start,
        uint48 duration
    ) external payable;
    /**
     *  @notice Extends the reward duration for `rewardToken` by `amount` tokens, extending the duration by the
     *          equivalent time according to the `rewardPerSec` rate of the pool.
     *  @param  rewardToken The reward token to extend
     *  @param  amount The additional reward amount to add
     */
    function extendReward(address rewardToken, uint256 amount) external payable;
    /**
     *  @notice Configures allocation points for a reward token over multiple staking tokens, setting the `allocPoints`
     *          for each `stakingTokens` and updating the `totalAllocPoint` for the `rewardToken`. The allocation
     *          points of any non-provided staking tokens will be left as-is, and won't be reset to zero.
     *  @param  rewardToken The reward token whose allocations are configured
     *  @param  stakingTokens The staking tokens to set allocation points for
     *  @param  allocPoints The allocation points for each staking token
     */
    function setAllocPoints(
        address rewardToken,
        IERC20[] calldata stakingTokens,
        uint48[] calldata allocPoints
    ) external;
    /**
     *  @notice Unregisters a reward token fully, immediately preventing users from ever harvesting their pending
     *          accumulated rewards. Optionally `pullTokens` can be set to false which causes the token balance to
     *          not be sent to the owner, this should only be set to false in case the token is bugged and reverts.
     *  @param  rewardToken The reward token to stop
     *  @param  receiver The address that receives the pulled token balance
     *  @param  pullTokens Whether to transfer the remaining token balance to the receiver
     */
    function stopReward(
        address rewardToken,
        address receiver,
        bool pullTokens
    ) external;

    /**
     *  @notice Returns the reward pools linked to the `stakingToken` alongside the pending rewards for `user`
     *          for these pools.
     *  @param  stakingToken The staking token whose linked reward pools are queried
     *  @param  user The user whose pending rewards are returned
     *  @return The reward token addresses
     *  @return The pending reward amounts, one per reward token
     */
    function getRewards(
        IERC20 stakingToken,
        address user
    ) external view returns (address[] memory, uint256[] memory);

    /// @notice Returns the allocation points for the `rewardToken` over all staking tokens linked to it.
    /// @param rewardToken The reward token to query
    /// @return stakingTokens The staking tokens linked to the reward token
    /// @return allocPoints The allocation points for each staking token
    function allocPointsByReward(
        address rewardToken
    )
        external
        view
        returns (IERC20[] memory stakingTokens, uint48[] memory allocPoints);
    /// @notice Returns the allocation points for the `stakingToken` over all reward tokens linked to it.
    /// @param stakingToken The staking token to query
    /// @return rewardTokens The reward tokens linked to the staking token
    /// @return allocPoints The allocation points for each reward token
    function allocPointsByStake(
        IERC20 stakingToken
    )
        external
        view
        returns (address[] memory rewardTokens, uint48[] memory allocPoints);

    /// @notice Returns all enabled reward tokens. Stopped reward tokens are not included, while ended rewards are.
    function rewardTokens() external view returns (address[] memory);
    /// @notice Returns the emission details of a `rewardToken`, configured via `setReward`.
    /// @param rewardToken The reward token to query
    /// @return The reward token's emission details
    function rewardDetails(
        address rewardToken
    ) external view returns (RewardDetails memory);
}
