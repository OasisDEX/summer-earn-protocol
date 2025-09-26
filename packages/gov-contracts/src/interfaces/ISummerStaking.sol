// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";

/**
 * @title ISummerStaking
 * @notice Interface for the staking module used by Governance v2. Users stake SUMR with optional lockups (0–3y),
 *         receiving non-transferable xSUMR 1:1 for governance while rewards are accounted on the weighted balance.
 * @dev Design highlights and invariants:
 *      - One aggregated NoLockup stake is always at index 0 for a portfolio (created lazily on first stake).
 *      - Lockups > 0 live at indices > 0. A user may have up to MAX_AMOUNT_OF_STAKES (see implementation constant).
 *      - Rewards are distributed on weighted balances; base `totalSupply` in the rewards manager tracks weighted sum.
 *      - Bucket caps are governor-controlled and can be 0 (disabled) or type(uint256).max (uncapped).
 *      - Early unstake penalties are forwarded to protocol treasury; no burn of SUMR occurs.
 *      - xSUMR mint/burn is delegated to approved staking modules; governance manages module roles on xSUMR.
 * @author Summer.fi Protocol
 */
interface ISummerStaking is IStakingRewardsManagerBase {
    // ============ ENUMS ============

    /**
     * @notice Lockup buckets categorizing stakes by lockup period duration
     * @dev Each bucket has configurable caps and different lockup period ranges
     */
    enum Bucket {
        NoLockup, // 0 days - immediate withdrawal with no lockup
        ShortTerm, // 1second - 14 days - disabled by default (cap = 0)
        TwoWeeksToThreeMonths, // <90 days - 2 weeks-3 months lockup period
        ThreeToSixMonths, // <180 days - 3-6 months lockup period
        SixToTwelveMonths, // <365 days - 6-12 month lockup period
        OneToTwoYears, // <730 days - 1-2 years lockup period
        TwoToThreeYears // <1095 days - 2-3 years lockup period
    }

    // ============ STRUCTS ============
    /**
     * @notice Structure representing a bucket's data
     * @param cap The maximum amount that can be staked in this bucket
     * @param staked The current total amount staked in this bucket
     */
    struct BucketData {
        uint256 cap;
        uint256 staked;
    }
    /**
     * @dev User stake element stored per portfolio. Implementation reserves index 0 for the no-lockup aggregate.
     *      For indices > 0, each element corresponds to an independent lockup position with its own end time.
     *      `weightedAmount` is precomputed to avoid recalculating the quadratic multiplier on every read.
     */
    /**
     * @notice Structure representing a user's individual stake with lockup details
     * @param amount The actual amount of tokens staked
     * @param weightedAmount The weighted amount used for reward calculations (amount * multiplier)
     * @param lockupEndTime Timestamp when the lockup period ends
     * @param lockupPeriod Original lockup period duration in seconds
     */
    struct UserStake {
        uint256 amount;
        uint256 weightedAmount;
        uint256 lockupEndTime;
        uint256 lockupPeriod;
    }

    // ============ STAKING FUNCTIONS ============

    /**
     * @notice Stake SUMMER tokens with a specified lockup period
     * @param _amount The amount of SUMMER tokens to stake (must be > 0)
     * @param _lockupPeriod The lockup period in seconds (0 to 3 years max)
     * @dev Creates a new stake with weighted amount calculated based on lockup period
     * @dev Transfers SUMMER tokens from caller and mints equivalent xSUMR tokens
     * @dev Weighted amount formula: amount * (1 + 7e-16 * lockupPeriod^2) using 60.18 fixed-point
     * @dev Emits StakedWithLockup and Staked events
     * @dev Reverts if amount is 0, lockup period exceeds max, or bucket cap exceeded
     */
    function stakeLockup(uint256 _amount, uint256 _lockupPeriod) external;

    /**
     * @notice Stake SUMMER tokens with lockup period on behalf of another address
     * @param _receiver The address that will receive the stake and xSUMR tokens
     * @param _amount The amount of SUMMER tokens to stake (must be > 0)
     * @param _lockupPeriod The lockup period in seconds (0 to 3 years max)
     * @dev SUMMER tokens are transferred from caller, but stake and xSUMR go to receiver
     * @dev Useful for protocol-level staking or delegation scenarios
     * @dev Same validation and mechanics as stakeLockup()
     */
    function stakeLockupOnBehalf(
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) external;

    // ============ UNSTAKING FUNCTIONS ============

    /**
     * @notice Unstake tokens from a specific stake position with penalty calculation
     * @param _stakeIndex The index of the stake to unstake from (0-based)
     * @param _amount The amount of tokens to unstake (must be > 0 and <= stake amount)
     * @dev can only be called by the wallet that owns the stake, there is no onBehalf version due to the penalty
     * @dev Applies penalty for early withdrawal based on remaining lockup time
     * @dev Penalty formula: penalty% = 2% if remaining time < 110 days otherwise (timeRemaining / maxLockupPeriod) * 20%
     * @dev Examples:
     *      - 3yr lockup, immediate unstake: 20% penalty
     *      - 3yr lockup, unstake after 1.5yr: 10% penalty
     *      - 1yr lockup, immediate unstake: ~6.67% penalty
     *      - After lockup ends: 0% penalty
     *      - 0 lockup, immediate unstake: 0% penalty
     *      - any lockup time, <110 days remaining: 2% penalty
     * @dev Penalties are sent to protocol treasury
     * @dev Emits UnstakedWithPenalty and Unstaked events
     * @dev Reverts if amount is 0, stake index invalid, or insufficient balance
     */
    function unstakeLockup(uint256 _stakeIndex, uint256 _amount) external;

    // ============ VIEW FUNCTIONS - STAKE INFORMATION ============

    /**
     * @notice Get the number of stakes for a specific user
     * @param _user The address to check stake count for
     * @return The total number of stakes (max 1000 per user)
     */
    function getUserStakesCount(address _user) external view returns (uint256);

    /**
     * @notice Get detailed information about a specific user stake
     * @param _user The address of the stake owner
     * @param _index The index of the stake to query (0-based)
     * @return amount The actual staked token amount
     * @return weightedAmount The weighted amount used for reward calculations
     * @return lockupEndTime Timestamp when lockup period ends
     * @return lockupPeriod Original lockup duration in seconds
     * @dev Returns zeros if index is out of bounds
     */
    function getUserStake(
        address _user,
        uint256 _index
    )
        external
        view
        returns (
            uint256 amount,
            uint256 weightedAmount,
            uint256 lockupEndTime,
            uint256 lockupPeriod
        );

    /**
     * @notice Get the weighted balance of an account for reward calculations
     * @param account The address to check weighted balance for
     * @return The total weighted balance (sum of all weighted stakes)
     * @dev This is the balance used for reward distribution calculations
     * @dev Different from balanceOf() which returns actual staked amount
     */
    function weightedBalanceOf(address account) external view returns (uint256);

    // ============ VIEW FUNCTIONS - PENALTY CALCULATIONS ============

    /**
     * @notice Calculate the penalty percentage for early unstaking
     * @param _user The address of the stake owner
     * @param _stakeIndex The index of the stake to calculate penalty for
     * @return The penalty percentage in WAD format (18 decimals)
     * @dev Returns 0 if lockup period has ended
     * @dev Formula: (timeRemaining / maxLockupPeriod) * maxPenalty
     * @dev maxPenalty = 2% floor < 110 days, else 20% (0.2e18), maxLockupPeriod = 3 years
     * @dev penaltyDisabled == true then 0
     */
    function calculatePenaltyPercentage(
        address _user,
        uint256 _stakeIndex
    ) external view returns (uint256);

    /**
     * @notice Calculate the penalty amount for unstaking a specific amount
     * @param _user The address of the stake owner
     * @param _amount The amount of tokens to unstake
     * @param _stakeIndex The index of the stake
     * @return The penalty amount in token units
     * @dev Penalty = (penaltyPercentage * amount) / WAD
     */
    function calculatePenalty(
        address _user,
        uint256 _amount,
        uint256 _stakeIndex
    ) external view returns (uint256);

    // ============ VIEW FUNCTIONS - WEIGHTED STAKE CALCULATIONS ============

    /**
     * @notice Calculate the weighted stake amount for a given amount and lockup period
     * @param _amount The base amount to stake
     * @param _lockupPeriod The lockup period in seconds
     * @return The weighted stake amount for reward calculations
     * @dev Formula: amount * (1 + 7e-16 * lockupPeriod^2) using 60.18 fixed-point
     * @dev Longer lockups result in higher weighted amounts and more rewards
     * @dev For 0 lockup period, multiplier is 1.0 (no boost)
     */
    function calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) external pure returns (uint256);

    // ============ VIEW FUNCTIONS - BUCKET MANAGEMENT ============

    /**
     * @notice Get the total staked amount for a specific lockup bucket
     * @param _bucket The bucket to check (NoLockup, ShortTerm, etc.)
     * @return The total amount staked in this bucket across all users
     */
    function getBucketTotalStaked(
        Bucket _bucket
    ) external view returns (uint256);

    /**
     * @notice Get comprehensive details about a specific lockup bucket
     * @param _bucket The bucket to query
     * @return cap The maximum amount that can be staked in this bucket
     * @return staked The current total amount staked in this bucket
     * @return minLockupPeriod The minimum lockup period for this bucket
     * @return maxLockupPeriod The maximum lockup period for this bucket
     * @dev cap = 0 means bucket is disabled, type(uint256).max means no cap
     */
    function getBucketDetails(
        Bucket _bucket
    )
        external
        view
        returns (
            uint256 cap,
            uint256 staked,
            uint256 minLockupPeriod,
            uint256 maxLockupPeriod
        );

    /**
     * @notice Get information about all lockup buckets at once
     * @return buckets Array of all bucket enums
     * @return caps Array of bucket caps (0 = disabled, max = no cap)
     * @return stakedAmounts Array of current staked amounts per bucket
     * @return minPeriods Array of minimum lockup periods per bucket
     * @return maxPeriods Array of maximum lockup periods per bucket
     * @dev Arrays are ordered: [NoLockup, ShortTerm, TwoWeeksToThreeMonths, ThreeToSixMonths, SixToTwelveMonths, OneToTwoYears, TwoToThreeYears]
     */
    function getAllBucketInfo()
        external
        view
        returns (
            Bucket[] memory buckets,
            uint256[] memory caps,
            uint256[] memory stakedAmounts,
            uint256[] memory minPeriods,
            uint256[] memory maxPeriods
        );

    // ============ ADMIN FUNCTIONS ============

    /**
     * @notice Update the staking cap for a specific lockup bucket
     * @param _bucket The bucket to update
     * @param _newCap The new cap amount (0 = disabled, type(uint256).max = no cap)
     * @dev Only callable by protocol governor
     * @dev Used to manage protocol risk and control staking distribution
     * @dev Emits LockupBucketUpdated event
     */
    function updateLockupBucketCap(Bucket _bucket, uint256 _newCap) external;

    /**
     * @notice Update the penalty enabled status
     * @param _penaltyEnabled The new penalty enabled status
     * @dev Only callable by protocol governor
     * @dev Used to manage protocol risk and control staking distribution
     * @dev Emits PenaltyEnabledUpdated event
     */
    function updatePenaltyEnabled(bool _penaltyEnabled) external;

    /**
     * @notice Rescues a token and transfers it to the new owner
     * @param _token The address of the token to rescue
     * @param _to The address of the new owner
     * @dev Only callable by protocol governor
     * @dev Used to rescue tokens in case of emergency
     */
    function rescueToken(address _token, address _to) external;

    // ============ EVENTS ============

    /**
     * @notice Emitted when tokens are staked with a lockup period
     * @param receiver The address that staked the tokens
     * @param stakeIndex The index of the stake that was staked
     * @param amount The amount of tokens staked
     * @param lockupPeriod The lockup period in seconds
     * @param weightedAmount The weighted amount calculated for rewards
     */
    event StakedWithLockup(
        address indexed receiver,
        uint256 indexed stakeIndex,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 weightedAmount
    );

    /**
     * @notice Emitted when tokens are unstaked with a penalty applied
     * @param receiver The owner of the stake that unstaked the tokens
     * @param stakeIndex The index of the stake that was unstaked
     * @param unstakedAmount The gross amount unstaked before penalty
     * @param penalty The penalty amount sent to treasury
     * @param returnAmount The net amount returned to user (unstakedAmount - penalty)
     */
    event UnstakedWithPenalty(
        address indexed receiver,
        uint256 indexed stakeIndex,
        uint256 unstakedAmount,
        uint256 penalty,
        uint256 returnAmount
    );

    /**
     * @notice Emitted when a lockup bucket cap is updated
     * @param bucket The bucket that was updated
     * @param cap The new cap amount (0 = disabled, max = unlimited)
     */
    event LockupBucketUpdated(Bucket indexed bucket, uint256 cap);

    /**
     * @notice Emitted when the penalty enabled status is updated
     * @param penaltyEnabled The new penalty enabled status
     */
    event PenaltyEnabledUpdated(bool penaltyEnabled);

    // ============ ERRORS ============

    /**
     * @notice Thrown when trying to use an invalid address (zero address)
     */
    error Staking_InvalidAddress(string message);

    /**
     * @notice Thrown when trying to use direct stake function instead of stakeLockup
     */
    error Staking_DirectStakeNotAllowed(string message);

    /**
     * @notice Thrown when trying to use direct unstake function instead of unstakeLockup
     */
    error Staking_DirectUnstakeNotAllowed(string message);

    /**
     * @notice Thrown when lockup period is invalid (too long, ended, etc.)
     */
    error Staking_InvalidLockupPeriod(string message);

    /**
     * @notice Thrown when stake index is invalid or out of bounds
     */
    error Staking_InvalidStakeIndex(string message);

    /**
     * @notice Thrown when trying to unstake more than available balance
     */
    error Staking_InsufficientBalance();

    /**
     * @notice Thrown when trying to use stakeOnBehalfOf (not supported)
     */
    error StakeOnBehalfOfNotSupported();

    /**
     * @notice Thrown when trying to use unstakeAndWithdrawOnBehalfOf (not supported)
     */
    error UnstakeOnBehalfOfNotSupported();

    /**
     * @notice Thrown when user has reached the maximum number of stakes allowed
     */
    error Staking_MaxStakesReached();

    /**
     * @notice Thrown when trying to stake amount that would exceed bucket cap
     */
    error Staking_BucketCapExceeded();

    /**
     * @notice Thrown when trying to stake/unstake amount that is invalid
     */
    error Staking_InvalidAmount(string message);
}
