// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {WrappedStakingToken} from "./WrappedStakingToken.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ConfigurationManaged} from "@summerfi/earn-protocol-contracts/contracts/ConfigurationManaged.sol";
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {ISummerStaking} from "../interfaces/ISummerStaking.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title SummerStaking
 * @notice Enhanced staking with lockups (0–3y), weighted rewards, and bucket caps. Users stake SUMR and receive xSUMR
 *         1:1 while rewards accrue on weighted balances computed via a quadratic time multiplier.
 *
 * @dev Architecture and invariants:
 *      - Index 0 of each portfolio aggregates all no-lockup stake; positions with lockup > 0 occupy indices > 0.
 *      - Weighted supply drives rewards accounting: `totalSupply` in base manager is the weighted sum.
 *      - Early unstake penalty: fixed 2% if remaining < FIXED_PENALTY_PERIOD, else linear up to 20% at 3 years.
 *      - Token flows: stake pulls SUMR, wraps internally, and mints xSUMR; unstake burns xSUMR, unwraps, and splits
 *        penalty to treasury.
 *      - Access control: governor manages bucket caps and penalty enablement; xSUMR roles managed on the token.
 *      - Reentrancy: public mutating entrypoints are nonReentrant and updateRewards for correct accounting.
 *
 *      Buckets & Caps (capacity control):
 *      - Each possible lockup duration maps to a discrete Bucket enum via `_findBucket(_lockupPeriod)`:
 *          • NoLockup:        0 seconds (min=0, max=0)
 *          • ShortTerm:       [1 second, 14 days]
 *          • TwoWeeksToThreeMonths: (14 days, 90 days]
 *          • ThreeToSixMonths:      (90 days, 180 days]
 *          • SixToTwelveMonths:     (180 days, 365 days]
 *          • OneToTwoYears:         (365 days, 730 days]
 *          • TwoToThreeYears:       (730 days, 1095 days]
 *
 *      - Bucket caps throttle the total raw SUMR that can be staked in each bucket. They are applied on the
 *        unweighted amount (plain token units), not the weighted amount used for rewards accounting.
 *        Cap semantics:
 *          • cap == 0                → bucket is disabled (any positive stake reverts with Staking_BucketCapExceeded)
 *          • cap == type(uint256).max → bucket is unlimited
 *          • 0 < cap < max           → currentRawStaked + amount must be <= cap
 */
contract SummerStaking is
    StakingRewardsManagerBase,
    ConfigurationManaged,
    ISummerStaking
{
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for IERC20;
    using SafeERC20 for IERC20;

    // ============ IMMUTABLE STATE ============

    IERC20 public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;
    WrappedStakingToken public immutable WRAPPED_SUMMER_TOKEN;

    // ============ CONSTANTS ============

    uint256 public constant MAX_LOCKUP_PERIOD = 3 * 365 days;
    uint256 public constant MAX_AMOUNT_OF_STAKES = 1000;
    uint256 public constant MIN_PENALTY_PERCENTAGE = 0.02e18; // 2%
    uint256 public constant MAX_PENALTY_PERCENTAGE = 0.2e18; // 20%
    uint256 public constant FIXED_PENALTY_PERIOD = 110 days;

    uint256 public constant WEIGHTED_STAKE_BASE = Constants.WAD; // 1 in 60.18 fixed-point
    uint256 public constant WEIGHTED_STAKE_COEFFICIENT = 700; // 7e-16 * 1e18 in 60.18 fixed-point

    uint256 public constant NO_LOCKUP_INDEX = 0;
    uint256 public constant BUCKET_SHORT_TERM_MIN = 1;
    uint256 public constant BUCKET_SHORT_TERM_MAX = 14 days;
    uint256 public constant BUCKET_TWO_WEEKS_TO_THREE_MONTHS_MAX = 90 days;
    uint256 public constant BUCKET_THREE_TO_SIX_MAX = 180 days;
    uint256 public constant BUCKET_SIX_TO_TWELVE_MAX = 365 days;
    uint256 public constant BUCKET_ONE_TO_TWO_MAX = 2 * 365 days;
    uint256 public constant BUCKET_TWO_TO_THREE_MAX = MAX_LOCKUP_PERIOD;

    // ============ STORAGE ============

    mapping(address owner => UserStake[] stakes) public stakesByOwner;

    mapping(address owner => uint256 weightedBalance) public weightedBalances;
    mapping(Bucket bucketId => BucketData bucketData) public bucketData;
    bool public penaltyEnabled = true;

    // ============ CONSTRUCTOR ============

    constructor(
        address _protocolAccessManager,
        address _configurationManager,
        address _summerToken,
        address _stakedSummerToken
    )
        StakingRewardsManagerBase(_protocolAccessManager)
        ConfigurationManaged(_configurationManager)
    {
        if (_summerToken == address(0)) {
            revert Staking_InvalidAddress(
                "Summer token address cannot be zero"
            );
        }
        if (_stakedSummerToken == address(0)) {
            revert Staking_InvalidAddress(
                "StakedSummerToken address cannot be zero"
            );
        }

        SUMMER_TOKEN = IERC20(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_stakedSummerToken);
        WRAPPED_SUMMER_TOKEN = new WrappedStakingToken(_summerToken);
        stakingToken = _summerToken;
    }

    // ============ EXTERNAL FUNCTIONS - STAKING ============

    ///  @inheritdoc ISummerStaking
    function stakeLockup(
        uint256 _amount,
        uint256 _lockupPeriod
    ) external nonReentrant {
        _stakeLockup(_msgSender(), _msgSender(), _amount, _lockupPeriod);
    }

    ///  @inheritdoc ISummerStaking
    function stakeLockupOnBehalf(
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) external nonReentrant {
        _stakeLockup(_msgSender(), _receiver, _amount, _lockupPeriod);
    }

    // ============ EXTERNAL FUNCTIONS - UNSTAKING ============

    ///  @inheritdoc ISummerStaking
    function unstakeLockup(
        uint256 _stakeIndex,
        uint256 _amount
    ) external virtual updateReward(_msgSender()) nonReentrant {
        // Validate amount and availability before reading stake
        if (_amount == 0) revert Staking_InvalidAmount("Amount cannot be zero");
        if (_amount > _balances[_msgSender()])
            revert Staking_InsufficientBalance();
        UserStake[] storage stakes = stakesByOwner[_msgSender()];
        if (_stakeIndex >= stakes.length)
            revert Staking_InvalidStakeIndex("Stake index out of bounds");

        // Copy stake to memory for mutation and proportional computations
        UserStake memory processedStake = stakes[_stakeIndex];
        if (processedStake.amount < _amount)
            revert Staking_InvalidStakeIndex(
                "Stake amount is less than unstake amount"
            );

        // Compute penalty and the weighted share we need to remove proportionally
        uint256 unstakePenalty = calculatePenalty(
            _msgSender(),
            _amount,
            _stakeIndex
        );
        // No overflow for any realistic amounts (e.g., 1e9 total supply with 18 decimals has >20 orders
        // of magnitude headroom). Proportional division truncates on partial unstakes; the final full exit
        // clears the remaining weighted exactly (no residual).
        uint256 weightedAmountToRemove = (processedStake.weightedAmount *
            _amount) / processedStake.amount;

        // Mutate local stake and persist back to storage (or pop if fully consumed and not index 0)
        processedStake.amount -= _amount;
        processedStake.weightedAmount -= weightedAmountToRemove;

        _updateBalancesOnUnstake(_msgSender(), _amount, weightedAmountToRemove);
        _subtractFromBucketTotal(processedStake.lockupPeriod, _amount);

        if (processedStake.amount == 0 && !_isNoLockupStakeIndex(_stakeIndex)) {
            _removeStake(stakes, _stakeIndex);
        } else {
            stakes[_stakeIndex] = processedStake;
        }

        // Perform token movements, including penalty routing to treasury if applicable
        _handleTokenTransfersOnUnstake(_msgSender(), _amount, unstakePenalty);

        emit UnstakedWithPenalty(
            _msgSender(),
            _stakeIndex,
            _amount,
            unstakePenalty,
            _amount - unstakePenalty
        );
        emit Unstaked(_msgSender(), _msgSender(), _amount);
    }

    // ============ EXTERNAL FUNCTIONS - ADMIN ============
    ///  @inheritdoc ISummerStaking
    function updateLockupBucketCap(
        Bucket _bucket,
        uint256 _newCap
    ) external onlyGovernor {
        // Governor may set to 0 (disabled) or max (no cap). Intermediate caps throttle bucket utilization.
        bucketData[_bucket].cap = _newCap;
        emit LockupBucketUpdated(_bucket, _newCap);
    }

    ///  @inheritdoc ISummerStaking
    function updatePenaltyEnabled(bool _penaltyEnabled) external onlyGovernor {
        // Toggling penalties is a risk lever; when disabled, early exits incur no treasury fee
        penaltyEnabled = _penaltyEnabled;
        emit PenaltyEnabledUpdated(_penaltyEnabled);
    }

    ///  @inheritdoc ISummerStaking
    function rescueToken(address _token, address _to) external onlyGovernor {
        if (_token == address(WRAPPED_SUMMER_TOKEN)) {
            revert Staking_InvalidAddress("Cannot rescue wrapped summer token");
        }
        // Sweep entire token balance to the target; used for emergency recovery only
        IERC20(_token).safeTransfer(
            _to,
            IERC20(_token).balanceOf(address(this))
        );
    }

    // ============ EXTERNAL VIEW FUNCTIONS - STAKE INFORMATION ============

    function getUserStakesCount(address _user) external view returns (uint256) {
        return stakesByOwner[_user].length;
    }

    ///  @inheritdoc ISummerStaking
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
        )
    {
        // Return zeroed tuple if index out-of-bounds
        UserStake[] storage stakes = stakesByOwner[_user];
        if (_index < stakes.length) {
            amount = stakes[_index].amount;
            weightedAmount = stakes[_index].weightedAmount;
            lockupEndTime = stakes[_index].lockupEndTime;
            lockupPeriod = stakes[_index].lockupPeriod;
        }
    }

    ///  @inheritdoc ISummerStaking
    function weightedBalanceOf(
        address account
    ) external view virtual returns (uint256) {
        return weightedBalances[account];
    }

    // ============ EXTERNAL VIEW FUNCTIONS - BUCKET INFORMATION ============

    ///  @inheritdoc ISummerStaking
    function getBucketTotalStaked(
        Bucket _bucket
    ) external view returns (uint256) {
        return bucketData[_bucket].staked;
    }

    ///  @inheritdoc ISummerStaking
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
        )
    {
        (cap, staked, minLockupPeriod, maxLockupPeriod) = _getBucketDetails(
            _bucket
        );
    }

    ///  @inheritdoc ISummerStaking
    function getAllBucketInfo()
        external
        view
        returns (
            Bucket[] memory buckets,
            uint256[] memory caps,
            uint256[] memory stakedAmounts,
            uint256[] memory minPeriods,
            uint256[] memory maxPeriods
        )
    {
        buckets = new Bucket[](7);
        caps = new uint256[](7);
        stakedAmounts = new uint256[](7);
        minPeriods = new uint256[](7);
        maxPeriods = new uint256[](7);

        buckets[0] = Bucket.NoLockup;
        buckets[1] = Bucket.ShortTerm;
        buckets[2] = Bucket.TwoWeeksToThreeMonths;
        buckets[3] = Bucket.ThreeToSixMonths;
        buckets[4] = Bucket.SixToTwelveMonths;
        buckets[5] = Bucket.OneToTwoYears;
        buckets[6] = Bucket.TwoToThreeYears;

        for (uint256 i = 0; i < 7; i++) {
            (
                caps[i],
                stakedAmounts[i],
                minPeriods[i],
                maxPeriods[i]
            ) = _getBucketDetails(buckets[i]);
        }
    }

    // ============ EXTERNAL VIEW FUNCTIONS - PENALTY CALCULATIONS ============

    ///  @inheritdoc ISummerStaking
    function calculatePenaltyPercentage(
        address _user,
        uint256 _stakeIndex
    ) public view returns (uint256) {
        // If penalties are globally disabled, early exits are free
        if (!penaltyEnabled) {
            return 0;
        }
        // Load stake; caller must pass a valid index (public functions ensure bounds)
        UserStake storage userStake = stakesByOwner[_user][_stakeIndex];

        // No penalty if lockup has already expired
        if (block.timestamp >= userStake.lockupEndTime) {
            return 0;
        }

        // Near-expiry fixed penalty floor to avoid cliff at zero
        uint256 timeRemaining = userStake.lockupEndTime - block.timestamp;
        if (timeRemaining < FIXED_PENALTY_PERIOD) {
            return MIN_PENALTY_PERCENTAGE;
        }
        // Linear ramp to MAX_PENALTY_PERCENTAGE at MAX_LOCKUP_PERIOD
        return (timeRemaining * MAX_PENALTY_PERCENTAGE) / MAX_LOCKUP_PERIOD;
    }

    ///  @inheritdoc ISummerStaking
    function calculatePenalty(
        address _user,
        uint256 _amount,
        uint256 _stakeIndex
    ) public view returns (uint256) {
        uint256 penaltyPercentage = calculatePenaltyPercentage(
            _user,
            _stakeIndex
        );
        return (penaltyPercentage * _amount) / Constants.WAD;
    }

    // ============ EXTERNAL PURE FUNCTIONS - WEIGHTED STAKE CALCULATIONS ============

    ///  @inheritdoc ISummerStaking
    function calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) public pure returns (uint256) {
        return _calculateWeightedStake(_amount, _lockupPeriod);
    }

    // ============ PUBLIC OVERRIDE FUNCTIONS - REWARDS ============

    ///  @inheritdoc IStakingRewardsManagerBase
    function earned(
        address account,
        address rewardToken
    )
        public
        view
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
        returns (uint256)
    {
        uint256 weightedBalance = weightedBalances[account];
        if (weightedBalance == 0) {
            return rewards[rewardToken][account];
        }

        return
            (weightedBalance *
                (rewardPerToken(rewardToken) -
                    userRewardPerTokenPaid[rewardToken][account])) /
            Constants.WAD +
            rewards[rewardToken][account];
    }

    // ============ PUBLIC OVERRIDE FUNCTIONS - DISABLED FUNCTIONS ============
    ///  @inheritdoc IStakingRewardsManagerBase
    function stakeOnBehalfOf(
        address,
        uint256
    ) external pure override(IStakingRewardsManagerBase) {
        revert StakeOnBehalfOfNotSupported();
    }

    ///  @inheritdoc IStakingRewardsManagerBase
    function unstakeAndWithdrawOnBehalfOf(
        address,
        uint256,
        bool
    ) external pure override(IStakingRewardsManagerBase) {
        revert UnstakeOnBehalfOfNotSupported();
    }

    ///  @inheritdoc IStakingRewardsManagerBase
    function stake(
        uint256
    )
        external
        virtual
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectStakeNotAllowed("Use stakeLockup instead");
    }

    ///  @inheritdoc IStakingRewardsManagerBase
    function unstake(
        uint256
    )
        external
        virtual
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeLockup instead");
    }

    ///  @inheritdoc IStakingRewardsManagerBase
    function exit()
        external
        pure
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeLockup instead");
    }

    // ============ INTERNAL FUNCTIONS - STAKING LOGIC ============

    /**
     * @notice Internal staking entrypoint that validates inputs, computes weighted amounts, updates accounting
     *         and emits stake events.
     * @dev Emits both `Staked` (from base manager) and `StakedWithLockup` (extended) events. Creates or updates
     *      the no-lockup aggregate stake at index 0 when `_lockupPeriod == 0`, otherwise appends a new stake.
     *      Reverts on invalid inputs, exceeding caps, or reaching per-user stake limit. Updates both raw and
     *      weighted balances and bucket totals, and performs token transfers/minting.
     * @param _from Address providing SUMR tokens (debited via transferFrom)
     * @param _receiver Address that receives the stake and xSUMR
     * @param _amount SUMR amount to stake (must be > 0)
     * @param _lockupPeriod Lockup duration in seconds (0..MAX_LOCKUP_PERIOD)
     * @custom:reverts Staking_InvalidAddress if `_from` or `_receiver` is zero
     * @custom:reverts Staking_InvalidAmount if `_amount == 0`
     * @custom:reverts Staking_InvalidLockupPeriod if `_lockupPeriod > MAX_LOCKUP_PERIOD`
     * @custom:reverts Staking_MaxStakesReached if user already has `MAX_AMOUNT_OF_STAKES`
     * @custom:reverts Staking_BucketCapExceeded if staking would exceed bucket cap
     */
    function _stakeLockup(
        address _from,
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal updateReward(_receiver) {
        // Validate addresses and parameters up-front to fail fast
        if (_receiver == address(0))
            revert Staking_InvalidAddress("Target address cannot be zero");
        if (_from == address(0))
            revert Staking_InvalidAddress("Sender address cannot be zero");
        if (_amount == 0) revert Staking_InvalidAmount("Amount cannot be zero");
        if (_lockupPeriod > MAX_LOCKUP_PERIOD) {
            revert Staking_InvalidLockupPeriod(
                "Lockup period cannot exceed 3 years"
            );
        }
        // Enforce per-portfolio stake count bound and bucket caps on raw amount
        if (stakesByOwner[_receiver].length >= MAX_AMOUNT_OF_STAKES) {
            revert Staking_MaxStakesReached();
        }
        if (_wouldExceedBucketCap(_lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        // Precompute weighted amount: amount * (1 + k * t^2) in UD60x18 fixed-point
        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            _lockupPeriod
        );
        UserStake[] storage _stakePortfolio = _ensurePortfolio(_receiver);

        uint256 _stakeIndex;
        if (_lockupPeriod == 0) {
            // Aggregate no-lockup at index 0 to save storage slots and simplify exits
            UserStake storage noLockupStake = _noLockupStake(_stakePortfolio);
            noLockupStake.amount += _amount;
            noLockupStake.weightedAmount += weightedAmount;
            noLockupStake.lockupEndTime = block.timestamp;
            _stakeIndex = NO_LOCKUP_INDEX;
        } else {
            // Append an independent lockup position
            _stakePortfolio.push(
                UserStake({
                    amount: _amount,
                    weightedAmount: weightedAmount,
                    lockupEndTime: block.timestamp + _lockupPeriod,
                    lockupPeriod: _lockupPeriod
                })
            );
            _stakeIndex = _stakePortfolio.length - 1;
        }
        // Update balances and bucket totals, then move tokens and mint xSUMR
        _updateBalancesOnStake(_receiver, _amount, weightedAmount);
        _addToBucketTotal(_lockupPeriod, _amount);
        _handleTokenTransfersOnStake(_from, _receiver, _amount);

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _stakeIndex,
            _amount,
            _lockupPeriod,
            weightedAmount
        );
    }

    // ============ INTERNAL FUNCTIONS - BUCKET MANAGEMENT ============
    /**
     * @notice Resolves the `Bucket` for a given lockup period.
     * @param _lockupPeriod Lockup duration in seconds
     * @return bucket The resolved bucket enum
     * @custom:reverts Staking_InvalidLockupPeriod if `_lockupPeriod` exceeds maximum allowed
     */
    function _findBucket(uint256 _lockupPeriod) internal pure returns (Bucket) {
        // Map the lockup duration to a discrete risk bucket; 0 is a dedicated no-lockup bucket
        if (_lockupPeriod == 0) return Bucket.NoLockup;
        if (_lockupPeriod <= BUCKET_SHORT_TERM_MAX) return Bucket.ShortTerm;
        if (_lockupPeriod <= BUCKET_TWO_WEEKS_TO_THREE_MONTHS_MAX)
            return Bucket.TwoWeeksToThreeMonths;
        if (_lockupPeriod <= BUCKET_THREE_TO_SIX_MAX)
            return Bucket.ThreeToSixMonths;
        if (_lockupPeriod <= BUCKET_SIX_TO_TWELVE_MAX)
            return Bucket.SixToTwelveMonths;
        if (_lockupPeriod <= BUCKET_ONE_TO_TWO_MAX) return Bucket.OneToTwoYears;
        if (_lockupPeriod <= BUCKET_TWO_TO_THREE_MAX)
            return Bucket.TwoToThreeYears;
        revert Staking_InvalidLockupPeriod(
            "Lockup period exceeds maximum allowed"
        );
    }
    /**
     * @notice Increases the total staked amount for the bucket of the given lockup period.
     * @param _lockupPeriod Lockup duration in seconds
     * @param _amount Raw amount to add to the bucket total
     */
    function _addToBucketTotal(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        // Increase current bucket raw staked total; used for cap enforcement and telemetry
        Bucket bucket = _findBucket(_lockupPeriod);
        bucketData[bucket].staked += _amount;
    }
    /**
     * @notice Decreases the total staked amount for the bucket of the given lockup period.
     * @param _lockupPeriod Lockup duration in seconds
     * @param _amount Raw amount to subtract from the bucket total
     */
    function _subtractFromBucketTotal(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        // Decrease current bucket raw staked total on exits (or partial exits)
        Bucket bucket = _findBucket(_lockupPeriod);
        bucketData[bucket].staked -= _amount;
    }
    /**
     * @notice Returns cap, current staked total, and min/max lockup bounds for a bucket.
     * @param _bucket The bucket to query
     * @return cap The staking cap for the bucket (0 = disabled, max = unlimited)
     * @return staked The current total raw amount staked in the bucket
     * @return minLockupPeriod Minimum lockup period in seconds for the bucket
     * @return maxLockupPeriod Maximum lockup period in seconds for the bucket
     */
    function _getBucketDetails(
        Bucket _bucket
    )
        internal
        view
        returns (
            uint256 cap,
            uint256 staked,
            uint256 minLockupPeriod,
            uint256 maxLockupPeriod
        )
    {
        cap = bucketData[_bucket].cap;
        staked = bucketData[_bucket].staked;

        if (_bucket == Bucket.NoLockup) {
            minLockupPeriod = 0;
            maxLockupPeriod = 0;
        } else if (_bucket == Bucket.ShortTerm) {
            minLockupPeriod = BUCKET_SHORT_TERM_MIN;
            maxLockupPeriod = BUCKET_SHORT_TERM_MAX;
        } else if (_bucket == Bucket.TwoWeeksToThreeMonths) {
            minLockupPeriod = BUCKET_SHORT_TERM_MAX + 1;
            maxLockupPeriod = BUCKET_TWO_WEEKS_TO_THREE_MONTHS_MAX;
        } else if (_bucket == Bucket.ThreeToSixMonths) {
            minLockupPeriod = BUCKET_TWO_WEEKS_TO_THREE_MONTHS_MAX + 1;
            maxLockupPeriod = BUCKET_THREE_TO_SIX_MAX;
        } else if (_bucket == Bucket.SixToTwelveMonths) {
            minLockupPeriod = BUCKET_THREE_TO_SIX_MAX + 1;
            maxLockupPeriod = BUCKET_SIX_TO_TWELVE_MAX;
        } else if (_bucket == Bucket.OneToTwoYears) {
            minLockupPeriod = BUCKET_SIX_TO_TWELVE_MAX + 1;
            maxLockupPeriod = BUCKET_ONE_TO_TWO_MAX;
        } else if (_bucket == Bucket.TwoToThreeYears) {
            minLockupPeriod = BUCKET_ONE_TO_TWO_MAX + 1;
            maxLockupPeriod = BUCKET_TWO_TO_THREE_MAX;
        }
    }
    /**
     * @notice Checks whether staking `_amount` with `_lockupPeriod` would exceed the bucket cap.
     * @param _lockupPeriod Lockup duration in seconds
     * @param _amount Raw amount to test
     * @return wouldExceed True if current bucket total + amount would exceed cap
     */
    function _wouldExceedBucketCap(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal view returns (bool) {
        // Compute `current + amount > cap` with cap==0 treated as disabled (always exceed)
        Bucket bucket = _findBucket(_lockupPeriod);
        uint256 currentBucketTotal = bucketData[bucket].staked;
        uint256 bucketCap = bucketData[bucket].cap;
        return (currentBucketTotal + _amount) > bucketCap;
    }

    // ============ INTERNAL FUNCTIONS - WEIGHTED STAKE CALCULATIONS ============
    /**
     * @notice Calculates the weighted stake used for rewards accounting.
     * @dev Uses 60.18 fixed-point arithmetic: weighted = amount * (WEIGHTED_STAKE_BASE + WEIGHTED_STAKE_COEFFICIENT * t^2)
     *      where t is `_lockupPeriod` seconds. Constants: BASE=1e18, COEFFICIENT=700 (i.e., 7e-16 scaled to 60.18).
     * @param _amount Raw stake amount
     * @param _lockupPeriod Lockup duration in seconds
     * @return weightedAmount The weighted amount applied to rewards `totalSupply`
     */
    function _calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal pure returns (uint256) {
        // Convert lockup seconds to UD60x18 and square for quadratic multiplier
        UD60x18 time = convert(_lockupPeriod);
        UD60x18 timeSquared = time.mul(time);

        // multiplier = BASE + COEFFICIENT * t^2 (scaled math); then multiply by raw amount
        UD60x18 multiplier = ud60x18(WEIGHTED_STAKE_COEFFICIENT)
            .mul(timeSquared)
            .add(ud60x18(WEIGHTED_STAKE_BASE));

        return ud60x18(_amount).mul(multiplier).unwrap();
    }

    // ============ INTERNAL FUNCTIONS - TOKEN TRANSFERS ============
    /**
     * @notice Handles token flows for stake: pull SUMR from `from`, wrap into `WRAPPED_SUMMER_TOKEN`, mint xSUMR to `receiver`.
     * @dev Uses SafeERC20 for transfers and forceApprove to set allowance for the wrapper.
     * @param from Source address providing SUMR via `transferFrom`
     * @param receiver Recipient of newly minted xSUMR
     * @param amount Amount of SUMR to move and mint 1:1 as xSUMR
     */
    function _handleTokenTransfersOnStake(
        address from,
        address receiver,
        uint amount
    ) internal {
        // Pull SUMR from the staker and approve the wrapper for exact amount
        SUMMER_TOKEN.safeTransferFrom(from, address(this), amount);
        SUMMER_TOKEN.forceApprove(address(WRAPPED_SUMMER_TOKEN), amount);
        // Wrap into internal accounting token and mint xSUMR 1:1 to the receiver
        WRAPPED_SUMMER_TOKEN.depositFor(address(this), amount);
        STAKED_SUMMER_TOKEN.mint(receiver, amount);
    }
    /**
     * @notice Handles token flows for unstake: withdraw wrapped SUMR,
     * @notice send net to `receiver`, penalty to `treasury`, and burn xSUMR.
     * @dev If `unstakePenalty == 0`, withdraw directly to receiver; otherwise withdraw to this contract, split net and penalty.
     * @param receiver Receiver of the unstaked SUMR net of penalty
     * @param amount Amount of SUMR being unstaked
     * @param unstakePenalty Penalty amount in SUMR sent to `treasury()`
     */
    function _handleTokenTransfersOnUnstake(
        address receiver,
        uint amount,
        uint unstakePenalty
    ) internal {
        if (unstakePenalty > 0) {
            // Withdraw wrapped SUMR to this contract, then split between user and treasury
            WRAPPED_SUMMER_TOKEN.withdrawTo(address(this), amount);
            SUMMER_TOKEN.safeTransfer(receiver, amount - unstakePenalty);
            SUMMER_TOKEN.safeTransfer(treasury(), unstakePenalty);
        } else {
            // Gas-optimal path: withdraw directly to the receiver if no penalty is due
            WRAPPED_SUMMER_TOKEN.withdrawTo(receiver, amount);
        }
        // Burn xSUMR from the receiver to maintain 1:1 accounting with SUMR backing
        STAKED_SUMMER_TOKEN.burnFrom(receiver, amount);
    }

    // ============ INTERNAL FUNCTIONS - BALANCE MANAGEMENT ============
    /**
     * @notice Updates raw and weighted balances and weighted total supply during stake.
     * @param _receiver Receiver whose balances are increased
     * @param _amount Raw amount added
     * @param _weightedAmount Weighted amount added to rewards `totalSupply`
     */
    function _updateBalancesOnStake(
        address _receiver,
        uint256 _amount,
        uint256 _weightedAmount
    ) internal {
        // Raw SUMR staking balance (used for xSUMR mint/burn) and weighted balance for rewards
        _balances[_receiver] += _amount;
        weightedBalances[_receiver] += _weightedAmount;
        totalSupply += _weightedAmount;
    }
    /**
     * @notice Updates raw and weighted balances and weighted total supply during unstake.
     * @param _receiver Receiver whose balances are decreased
     * @param _amount Raw amount removed
     * @param _weightedAmount Weighted amount removed from rewards `totalSupply`
     */
    function _updateBalancesOnUnstake(
        address _receiver,
        uint256 _amount,
        uint256 _weightedAmount
    ) internal {
        // Mirror updates from stake but in reverse; maintain total weighted supply invariant
        _balances[_receiver] -= _amount;
        weightedBalances[_receiver] -= _weightedAmount;
        totalSupply -= _weightedAmount;
    }

    /**
     * @notice Removes a stake at `_index` from a user's portfolio using swap-and-pop.
     * @dev Assumes caller validated `_index` bounds. This is only used for non-aggregate stakes (index > 0).
     * @param _stakes The stakes to remove from
     * @param _index The index to remove (0-based)
     */
    function _removeStake(
        UserStake[] storage _stakes,
        uint256 _index
    ) internal {
        _stakes[_index] = _stakes[_stakes.length - 1];
        _stakes.pop();
    }
    // ============ INTERNAL FUNCTIONS - INDEX HELPERS ============
    /**
     * @notice Check if the index is the no lockup index
     * @param index The index to check
     * @return True if the index is the no lockup index, false otherwise
     */
    function _isNoLockupStakeIndex(uint256 index) internal pure returns (bool) {
        return index == NO_LOCKUP_INDEX;
    }
    /**
     * @notice Get the no lockup stake for a given portfolio
     * @param portfolio The portfolio to get the no lockup stake for
     * @return The no lockup stake for the portfolio
     */
    function _noLockupStake(
        UserStake[] storage portfolio
    ) internal view returns (UserStake storage) {
        return portfolio[NO_LOCKUP_INDEX];
    }

    // ============ INTERNAL - ID HELPERS ============

    /**
     * @notice Ensure a portfolio for a given owner address
     * @param owner The address to ensure an id for
     * @return The portfolio for the address
     */
    function _ensurePortfolio(
        address owner
    ) internal returns (UserStake[] storage) {
        if (stakesByOwner[owner].length == 0) {
            stakesByOwner[owner].push(
                UserStake({
                    amount: 0,
                    weightedAmount: 0,
                    lockupEndTime: block.timestamp,
                    lockupPeriod: 0
                })
            );
        }
        return stakesByOwner[owner];
    }
}
