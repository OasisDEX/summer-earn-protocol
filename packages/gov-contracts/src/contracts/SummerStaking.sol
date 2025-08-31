// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {WrappedStakingToken} from "./WrappedStakingToken.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ConfigurationManaged} from "@summerfi/earn-protocol-contracts/contracts/ConfigurationManaged.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";

// @dev Enhanced staking contract with lockup periods and reward distribution
// @dev Users can stake with any lockup period, rewards are calculated based on weighted stakes
contract SummerStaking is StakingRewardsManagerBase, ConfigurationManaged {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;
    using EnumerableMap for EnumerableMap.UintToUintMap;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;

    // Lockup configuration
    uint256 public constant MAX_LOCKUP_PERIOD = 4 * 365 days; // 4 years
    uint256 public constant MAX_AMOUNT_OF_STAKES = 10; // Maximum number of stakes per user
    uint256 public constant MAX_PENALTY_PERCENTAGE = 50; // 50%

    // Bucket enum for clear indexing
    enum Bucket {
        NoLockup, // 0 days
        ShortTerm, // 1-90 days (disabled by default with cap 0)
        ThreeToSixMonths, // 90-180 days
        SixToTwelveMonths, // 180-365 days
        OneToTwoYears, // 365-730 days
        TwoToFourYears // 731+ days
    }

    // Bucket period boundaries (in seconds)
    uint256 public constant BUCKET_SHORT_TERM_MAX = 90 days - 1;
    uint256 public constant BUCKET_THREE_TO_SIX_MAX = 180 days;
    uint256 public constant BUCKET_SIX_TO_TWELVE_MAX = 365 days;
    uint256 public constant BUCKET_ONE_TO_TWO_MAX = 730 days;
    uint256 public constant BUCKET_TWO_TO_FOUR_MAX = MAX_LOCKUP_PERIOD;

    // Weighted stake calculation constants
    uint256 private constant WEIGHTED_STAKE_BASE = 5e16; // 0.05 in 60.18 fixed-point
    uint256 private constant WEIGHTED_STAKE_COEFFICIENT = 4e2; // 4e-16 * 1e18 = 400 in 60.18 fixed-point

    // User stake information with lockup details
    struct UserStake {
        uint256 amount; // Actual staked amount
        uint256 weightedAmount; // Weighted amount for reward calculations
        uint256 lockupEndTime; // Timestamp when lockup ends
        uint256 lockupPeriod; // Original lockup period in seconds
    }

    // Mapping: user => their stakes (multiple stakes allowed)
    mapping(address => UserStake[]) public userStakes;

    // Mapping: user => total weighted staked amount
    mapping(address => uint256) private _weightedBalances;

    // Bucket management using enum keys
    mapping(Bucket => uint256) private _bucketCap;
    mapping(Bucket => uint256) private _bucketStaked;

    // Events for bucket management
    event LockupBucketUpdated(
        Bucket indexed bucket,
        uint256 cap,
        uint256 maxLockupPeriod
    );
    event LockupBucketAdded(
        Bucket indexed bucket,
        uint256 cap,
        uint256 minLockupPeriod,
        uint256 maxLockupPeriod
    );

    // Wrapped version of staking token for internal accounting
    address public immutable wrappedStakingToken;

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

        SUMMER_TOKEN = ISummerToken(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_stakedSummerToken);

        wrappedStakingToken = address(new WrappedStakingToken(_summerToken));
        stakingToken = _summerToken;

        // Initialize default lockup bucket configurations
        _initializeDefaultLockupBuckets();
    }

    /**
     * @notice Initialize default lockup bucket configurations
     * @dev Creates buckets for all lockup periods including ShortTerm (disabled by default)
     * @dev ShortTerm bucket has cap 0 to disable it, others have no cap (type(uint256).max)
     */
    function _initializeDefaultLockupBuckets() internal {
        // NoLockup bucket - no cap
        _bucketCap[Bucket.NoLockup] = type(uint256).max;
        _bucketStaked[Bucket.NoLockup] = 0;

        // ShortTerm bucket - disabled by default (cap 0)
        _bucketCap[Bucket.ShortTerm] = 0;
        _bucketStaked[Bucket.ShortTerm] = 0;

        // ThreeToSixMonths bucket - no cap
        _bucketCap[Bucket.ThreeToSixMonths] = 0;
        _bucketStaked[Bucket.ThreeToSixMonths] = 0;

        // SixToTwelveMonths bucket - no cap
        _bucketCap[Bucket.SixToTwelveMonths] = 0;
        _bucketStaked[Bucket.SixToTwelveMonths] = 0;

        // OneToTwoYears bucket - no cap
        _bucketCap[Bucket.OneToTwoYears] = 0;
        _bucketStaked[Bucket.OneToTwoYears] = 0;

        // TwoToFourYears bucket - no cap
        _bucketCap[Bucket.TwoToFourYears] = type(uint256).max;
        _bucketStaked[Bucket.TwoToFourYears] = 0;
    }

    /**
     * @notice Update the cap for a specific lockup bucket
     * @param _bucket The bucket to update
     * @param _newCap The new cap amount (0 = disabled, type(uint256).max = no cap)
     * @dev Only callable by governor
     */
    function updateLockupBucketCap(
        Bucket _bucket,
        uint256 _newCap
    ) external onlyGovernor {
        _bucketCap[_bucket] = _newCap;

        // Get the max lockup period for this bucket for the event
        uint256 maxLockupPeriod = _getBucketMaxLockupPeriod(_bucket);

        emit LockupBucketUpdated(_bucket, _newCap, maxLockupPeriod);
    }

    /**
     * @notice Get the total staked amount for a specific lockup bucket
     * @param _bucket The bucket to check
     * @return The total staked amount in this bucket
     */
    function getBucketTotalStaked(
        Bucket _bucket
    ) external view returns (uint256) {
        return _bucketStaked[_bucket];
    }

    /**
     * @notice Find which bucket a lockup period belongs to
     * @param _lockupPeriod The lockup period in seconds
     * @return The bucket enum value
     */
    function _findBucket(uint256 _lockupPeriod) internal pure returns (Bucket) {
        if (_lockupPeriod == 0) {
            return Bucket.NoLockup;
        }
        if (_lockupPeriod <= BUCKET_SHORT_TERM_MAX) {
            return Bucket.ShortTerm;
        }
        if (_lockupPeriod <= BUCKET_THREE_TO_SIX_MAX) {
            return Bucket.ThreeToSixMonths;
        }
        if (_lockupPeriod <= BUCKET_SIX_TO_TWELVE_MAX) {
            return Bucket.SixToTwelveMonths;
        }
        if (_lockupPeriod <= BUCKET_ONE_TO_TWO_MAX) {
            return Bucket.OneToTwoYears;
        }
        if (_lockupPeriod <= BUCKET_TWO_TO_FOUR_MAX) {
            return Bucket.TwoToFourYears;
        }
        revert Staking_InvalidLockupPeriod(
            "Lockup period exceeds maximum allowed"
        );
    }

    /**
     * @notice Get the maximum lockup period for a bucket
     * @param _bucket The bucket to check
     * @return The maximum lockup period in seconds
     */
    function _getBucketMaxLockupPeriod(
        Bucket _bucket
    ) internal pure returns (uint256) {
        if (_bucket == Bucket.NoLockup) return 0;
        if (_bucket == Bucket.ShortTerm) return BUCKET_SHORT_TERM_MAX;
        if (_bucket == Bucket.ThreeToSixMonths) return BUCKET_THREE_TO_SIX_MAX;
        if (_bucket == Bucket.SixToTwelveMonths)
            return BUCKET_SIX_TO_TWELVE_MAX;
        if (_bucket == Bucket.OneToTwoYears) return BUCKET_ONE_TO_TWO_MAX;
        if (_bucket == Bucket.TwoToFourYears) return BUCKET_TWO_TO_FOUR_MAX;
        revert Staking_InvalidBucketIndex();
    }

    /**
     * @notice Update bucket totals when adding stake
     * @param _lockupPeriod The lockup period of the stake
     * @param _amount The amount being added
     */
    function _updateBucketTotalOnAdd(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        Bucket bucket = _findBucket(_lockupPeriod);
        _bucketStaked[bucket] += _amount;
    }

    /**
     * @notice Update bucket totals when removing stake
     * @param _lockupPeriod The lockup period of the stake
     * @param _amount The amount being removed
     */
    function _updateBucketTotalOnRemove(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        Bucket bucket = _findBucket(_lockupPeriod);
        _bucketStaked[bucket] -= _amount;
    }

    /**
     * @notice Check if staking would exceed the bucket cap
     * @param _lockupPeriod The lockup period for the new stake
     * @param _amount The amount to stake
     * @return True if the stake would exceed the bucket cap
     */
    function _wouldExceedBucketCap(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal view returns (bool) {
        Bucket bucket = _findBucket(_lockupPeriod);
        uint256 currentBucketTotal = _bucketStaked[bucket];
        uint256 bucketCap = _bucketCap[bucket];

        // // If cap is 0, bucket is disabled
        // if (bucketCap == 0) {
        //     return true;
        // }

        // // If cap is type(uint256).max, no cap
        // if (bucketCap == type(uint256).max) {
        //     return false;
        // }

        return (currentBucketTotal + _amount) > bucketCap;
    }

    /**
     * @notice Stake on behalf of another address (not supported)
     * @dev This operation is not supported and will revert
     */
    function stakeOnBehalfOf(address, uint256) external pure override {
        revert StakeOnBehalfOfNotSupported();
    }

    /**
     * @notice Unstake and withdraw on behalf of another address (not supported)
     * @dev This operation is not supported and will revert
     */
    function unstakeAndWithdrawOnBehalfOf(
        address,
        uint256,
        bool
    ) external pure override {
        revert UnstakeOnBehalfOfNotSupported();
    }

    /**
     * @notice Direct stake function (not allowed)
     * @dev Users must use stakeWithNewLockup instead
     */
    function stake(uint256) public virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithNewLockup instead");
    }

    /**
     * @notice Direct unstake function (not allowed)
     * @dev Users must use unstakeFromLockup instead
     */
    function unstake(uint256) public virtual override {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeFromLockup instead");
    }

    /**
     * @notice Unstake tokens from a specific lockup with potential penalties
     * @param _stakeIndex The index of the stake to unstake from
     * @param _amount The amount of tokens to unstake
     * @dev Applies penalties for early unstaking based on remaining lockup time
     */
    function unstakeFromLockup(
        uint256 _stakeIndex,
        uint256 _amount
    ) public virtual updateReward(_msgSender()) {
        if (_amount == 0) revert CannotUnstakeZero();
        if (_amount > _balances[_msgSender()])
            revert Staking_InsufficientBalance();
        if (_stakeIndex >= userStakes[_msgSender()].length)
            revert Staking_InvalidStakeIndex();
        UserStake memory processedStake = userStakes[_msgSender()][_stakeIndex];
        if (processedStake.amount == 0) revert Staking_InvalidStakeIndex();

        uint256 unstakePenaltyPercentage = calculatePenalty(
            _msgSender(),
            _stakeIndex
        );
        uint256 unstakePenalty = (_amount * unstakePenaltyPercentage) /
            Constants.WAD;

        uint256 weightedAmountToRemove = (processedStake.weightedAmount *
            _amount) / processedStake.amount;
        processedStake.amount -= _amount;
        processedStake.weightedAmount -= weightedAmountToRemove;

        // Update totals
        _balances[_msgSender()] -= _amount;
        _weightedBalances[_msgSender()] -= weightedAmountToRemove;
        totalSupply -= weightedAmountToRemove;

        // Update bucket totals
        _updateBucketTotalOnRemove(processedStake.lockupPeriod, _amount);

        // Remove empty processedStake
        if (processedStake.amount == 0) {
            _removeStake(_msgSender(), _stakeIndex);
        } else {
            userStakes[_msgSender()][_stakeIndex] = processedStake;
        }
        // Burn staked tokens and return SUMMER tokens from wrapped token
        _burn(_amount);

        WrappedStakingToken(wrappedStakingToken).withdrawTo(
            address(this),
            _amount
        );
        SUMMER_TOKEN.safeTransfer(_msgSender(), _amount - unstakePenalty);
        SUMMER_TOKEN.safeTransfer(treasury(), unstakePenalty);

        emit UnstakedWithPenalty(
            _msgSender(),
            _amount,
            unstakePenalty,
            _amount - unstakePenalty
        );
        emit Unstaked(_msgSender(), _msgSender(), _amount);
    }

    /**
     * @notice Stake tokens with a lockup period
     * @param _amount The amount of SUMMER tokens to stake
     * @param _lockupPeriod The lockup period in seconds (0 to 4 years)
     */
    function stakeWithNewLockup(
        uint256 _amount,
        uint256 _lockupPeriod
    ) external updateReward(_msgSender()) {
        _stakeWithLockup(_msgSender(), _msgSender(), _amount, _lockupPeriod);
    }

    /**
     * @notice Add more tokens to an existing stake
     * @param _stakeIndex The index of the existing stake to add to
     * @param _amount The amount of SUMMER tokens to add
     * @dev The lockup period must still be active to add to a stake
     */
    function addToStake(
        uint256 _stakeIndex,
        uint256 _amount
    ) external updateReward(_msgSender()) {
        if (_stakeIndex >= userStakes[_msgSender()].length)
            revert Staking_InvalidStakeIndex();
        UserStake storage existingStake = userStakes[_msgSender()][_stakeIndex];
        if (existingStake.amount == 0) revert Staking_InvalidStakeIndex();
        if (existingStake.lockupEndTime < block.timestamp)
            revert Staking_InvalidLockupPeriod("Lockup period has ended");

        // Check if adding to stake would exceed bucket cap
        uint256 remainingTime = existingStake.lockupEndTime - block.timestamp;
        if (_wouldExceedBucketCap(existingStake.lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        SUMMER_TOKEN.safeTransferFrom(_msgSender(), address(this), _amount);
        SUMMER_TOKEN.forceApprove(wrappedStakingToken, _amount);
        WrappedStakingToken(wrappedStakingToken).depositFor(
            address(this),
            _amount
        );

        // Mint equivalent amount of governance tokens
        _mint(_msgSender(), _amount);

        // Calculate weighted amount based on lockup period
        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            remainingTime
        );

        existingStake.amount += _amount;
        existingStake.weightedAmount += weightedAmount;
        _balances[_msgSender()] += _amount;
        _weightedBalances[_msgSender()] += weightedAmount;
        totalSupply += weightedAmount;

        // Update bucket totals
        _updateBucketTotalOnAdd(remainingTime, _amount);

        emit Staked(_msgSender(), _msgSender(), _amount);
        emit StakedWithLockup(
            _msgSender(),
            _amount,
            remainingTime,
            weightedAmount
        );
    }
    /**
     * @notice Internal function to stake with lockup
     * @param _from The address to transfer tokens from
     * @param _receiver The address to receive the stake
     * @param _amount The amount of SUMMER tokens to stake
     * @param _lockupPeriod The lockup period in seconds
     */
    function _stakeWithLockup(
        address _from,
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal {
        if (_receiver == address(0)) revert CannotStakeToZeroAddress();
        if (_amount == 0) revert CannotStakeZero();
        if (_lockupPeriod > MAX_LOCKUP_PERIOD) {
            revert Staking_InvalidLockupPeriod(
                "Lockup period cannot exceed 4 years"
            );
        }

        if (userStakes[_receiver].length >= MAX_AMOUNT_OF_STAKES) {
            revert Staking_MaxStakesReached();
        }

        // Check if staking would exceed bucket cap
        if (_wouldExceedBucketCap(_lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        // Transfer SUMMER tokens from user to contract and wrap them
        SUMMER_TOKEN.safeTransferFrom(_from, address(this), _amount);
        SUMMER_TOKEN.forceApprove(wrappedStakingToken, _amount);
        WrappedStakingToken(wrappedStakingToken).depositFor(
            address(this),
            _amount
        );

        // Mint equivalent amount of governance tokens
        _mint(_receiver, _amount);

        // Calculate weighted amount based on lockup period
        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            _lockupPeriod
        );

        // Create new stake entry
        UserStake memory newStake = UserStake({
            amount: _amount,
            weightedAmount: weightedAmount,
            lockupEndTime: block.timestamp + _lockupPeriod,
            lockupPeriod: _lockupPeriod
        });

        // Add stake to user's stakes array
        userStakes[_receiver].push(newStake);

        // Update user's total staked amounts
        _balances[_receiver] += _amount;
        _weightedBalances[_receiver] += weightedAmount;

        // Update global totals (weighted amount for reward calculations)
        // totalSupply is used in rewardPerToken function that we can't override
        totalSupply += weightedAmount;

        // Update bucket totals
        _updateBucketTotalOnAdd(_lockupPeriod, _amount);

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _amount,
            _lockupPeriod,
            weightedAmount
        );
    }
    /**
     * @notice Get bucket details including cap and staked amounts
     * @param _bucket The bucket to check
     * @return cap The cap for this bucket
     * @return staked The total staked amount in this bucket
     * @return minLockupPeriod The minimum lockup period for this bucket
     * @return maxLockupPeriod The maximum lockup period for this bucket
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
        )
    {
        cap = _bucketCap[_bucket];
        staked = _bucketStaked[_bucket];

        if (_bucket == Bucket.NoLockup) {
            minLockupPeriod = 0;
            maxLockupPeriod = 0;
        } else if (_bucket == Bucket.ShortTerm) {
            minLockupPeriod = 1 seconds;
            maxLockupPeriod = BUCKET_SHORT_TERM_MAX;
        } else if (_bucket == Bucket.ThreeToSixMonths) {
            minLockupPeriod = BUCKET_SHORT_TERM_MAX + 1;
            maxLockupPeriod = BUCKET_THREE_TO_SIX_MAX;
        } else if (_bucket == Bucket.SixToTwelveMonths) {
            minLockupPeriod = BUCKET_THREE_TO_SIX_MAX + 1;
            maxLockupPeriod = BUCKET_SIX_TO_TWELVE_MAX;
        } else if (_bucket == Bucket.OneToTwoYears) {
            minLockupPeriod = BUCKET_SIX_TO_TWELVE_MAX + 1;
            maxLockupPeriod = BUCKET_ONE_TO_TWO_MAX;
        } else if (_bucket == Bucket.TwoToFourYears) {
            minLockupPeriod = BUCKET_ONE_TO_TWO_MAX + 1;
            maxLockupPeriod = BUCKET_TWO_TO_FOUR_MAX;
        }
    }
    /**
     * @notice Calculate the weighted stake amount based on lockup period
     * @param _amount The base amount to stake
     * @param _lockupPeriod The lockup period in seconds
     * @return The weighted stake amount for reward calculations
     * @dev Uses formula: amount * (4E-16 * time^2 + 0.05)
     * @dev For 0 lockup period, returns the original amount (no weighting)
     */
    function calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) public pure returns (uint256) {
        return _calculateWeightedStake(_amount, _lockupPeriod);
    }

    function _calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal pure returns (uint256) {
        if (_lockupPeriod == 0) {
            return _amount; // No weighting for 0 lockup
        }

        // Convert lockupPeriod into 60.18 fixed-point
        UD60x18 time = convert(_lockupPeriod);

        // Square it safely in 60.18 format
        UD60x18 timeSquared = time.mul(time);

        // multiplier = (WEIGHTED_STAKE_COEFFICIENT * time^2) + WEIGHTED_STAKE_BASE
        UD60x18 multiplier = ud60x18(WEIGHTED_STAKE_COEFFICIENT)
            .mul(timeSquared)
            .add(ud60x18(WEIGHTED_STAKE_BASE));

        // weightedAmount = amount * multiplier
        return ud60x18(_amount).mul(multiplier).unwrap();
    }

    /**
     * @notice Get the weighted stake balance for reward calculations
     * @param account The address to check balance for
     * @return The weighted stake balance
     */
    function weightedBalanceOf(
        address account
    ) public view virtual returns (uint256) {
        return _weightedBalances[account];
    }

    /**
     * @notice Calculate penalty for early unstaking
     * @param _stakeIndex The index of the stake to calculate penalty for
     * @return The penalty amount in WAD
     * @dev Penalty formula: penalty = weighted_amount × 50% × (time_remaining / original_lockup_period)
     * @dev Examples:
     *      - 4-year lockup, unstake immediately: 50% penalty
     *      - 4-year lockup, unstake after 2 years: 25% penalty
     *      - 4-year lockup, unstake after 4 years: 0% penalty
     *      - 1-year lockup, unstake immediately: 12.5% penalty
     *      - 2-year lockup, unstake immediately: 25% penalty
     */
    function calculatePenalty(
        address _user,
        uint256 _stakeIndex
    ) public view returns (uint256) {
        UserStake storage userStake = userStakes[_user][_stakeIndex];

        if (block.timestamp >= userStake.lockupEndTime) {
            return 0; // No penalty if lockup period has ended
        }

        uint256 timeRemaining = userStake.lockupEndTime - block.timestamp;
        // Penalty percentage = 50% * (time_remaining / original_lockup_period)
        uint256 penaltyPercentage = (timeRemaining * 50 * Constants.WAD) /
            (userStake.lockupPeriod * 100);

        // Penalty amount = amount * penalty_percentage
        return penaltyPercentage;
    }

    /**
     * @notice Remove a stake from the user's stakes array
     * @param _user The user address
     * @param _index The index to remove
     */
    function _removeStake(address _user, uint256 _index) internal {
        UserStake[] storage stakes = userStakes[_user];
        if (_index >= stakes.length) return;

        // Move the last element to the position being removed
        stakes[_index] = stakes[stakes.length - 1];
        stakes.pop();
    }

    /**
     * @notice Get the number of stakes for a user
     * @param _user The user address
     * @return The number of stakes
     */
    function getUserStakesCount(address _user) external view returns (uint256) {
        return userStakes[_user].length;
    }

    /**
     * @notice Get stake details for a user
     * @param _user The user address
     * @param _index The stake index
     * @return amount The staked amount
     * @return weightedAmount The weighted amount
     * @return lockupEndTime The lockup end time
     * @return lockupPeriod The lockup period
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
        )
    {
        if (_index < userStakes[_user].length) {
            amount = userStakes[_user][_index].amount;
            weightedAmount = userStakes[_user][_index].weightedAmount;
            lockupEndTime = userStakes[_user][_index].lockupEndTime;
            lockupPeriod = userStakes[_user][_index].lockupPeriod;
        }
    }

    /**
     * @notice Override _stake to prevent direct usage - users must use stakeWithNewLockup
     * @dev This function is overridden to enforce lockup-based staking
     */
    function _stake(address, address, uint256) internal virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithNewLockup instead");
    }

    /**
     * @notice Burn staked tokens when unstaking
     * @param _amount The amount of tokens to burn
     * @dev Transfers tokens from user to contract and burns them
     */
    function _burn(uint256 _amount) internal {
        STAKED_SUMMER_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).burn(_amount);
    }

    /**
     * @notice Mint staked tokens when staking
     * @param _user The user to mint tokens for
     * @param _amount The amount of tokens to mint
     * @dev Mints new staked tokens to the user
     */
    function _mint(address _user, uint256 _amount) internal {
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).mint(_user, _amount);
    }

    /**
     * @notice Calculate earned rewards for an account using weighted stakes
     * @param account The account to calculate earnings for
     * @param rewardToken The reward token
     * @return The earned reward amount
     */
    function earned(
        address account,
        address rewardToken
    ) public view override returns (uint256) {
        uint256 weightedBalance = _weightedBalances[account];
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
    /**
     * @notice Exit function to unstake all and claim rewards (not allowed)
     * @dev Users must use unstakeFromLockup instead for individual stakes
     * @dev This function is overridden to prevent direct usage
     */
    function exit() public pure override {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeFromLockup instead");
    }

    /**
     * @notice Get information about all buckets
     * @return buckets Array of bucket enums
     * @return caps Array of bucket caps
     * @return stakedAmounts Array of staked amounts
     * @return minPeriods Array of minimum lockup periods
     * @return maxPeriods Array of maximum lockup periods
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
        )
    {
        buckets = new Bucket[](6);
        caps = new uint256[](6);
        stakedAmounts = new uint256[](6);
        minPeriods = new uint256[](6);
        maxPeriods = new uint256[](6);

        buckets[0] = Bucket.NoLockup;
        buckets[1] = Bucket.ShortTerm;
        buckets[2] = Bucket.ThreeToSixMonths;
        buckets[3] = Bucket.SixToTwelveMonths;
        buckets[4] = Bucket.OneToTwoYears;
        buckets[5] = Bucket.TwoToFourYears;

        for (uint256 i = 0; i < 6; i++) {
            Bucket bucket = buckets[i];
            caps[i] = _bucketCap[bucket];
            stakedAmounts[i] = _bucketStaked[bucket];

            if (bucket == Bucket.NoLockup) {
                minPeriods[i] = 0;
                maxPeriods[i] = 0;
            } else if (bucket == Bucket.ShortTerm) {
                minPeriods[i] = 1 days;
                maxPeriods[i] = BUCKET_SHORT_TERM_MAX;
            } else if (bucket == Bucket.ThreeToSixMonths) {
                minPeriods[i] = BUCKET_SHORT_TERM_MAX + 1;
                maxPeriods[i] = BUCKET_THREE_TO_SIX_MAX;
            } else if (bucket == Bucket.SixToTwelveMonths) {
                minPeriods[i] = BUCKET_THREE_TO_SIX_MAX + 1;
                maxPeriods[i] = BUCKET_SIX_TO_TWELVE_MAX;
            } else if (bucket == Bucket.OneToTwoYears) {
                minPeriods[i] = BUCKET_SIX_TO_TWELVE_MAX + 1;
                maxPeriods[i] = BUCKET_ONE_TO_TWO_MAX;
            } else if (bucket == Bucket.TwoToFourYears) {
                minPeriods[i] = BUCKET_ONE_TO_TWO_MAX + 1;
                maxPeriods[i] = BUCKET_TWO_TO_FOUR_MAX;
            }
        }
    }

    // Custom errors
    error Staking_InvalidAddress(string message);
    error Staking_DirectStakeNotAllowed(string message);
    error Staking_DirectUnstakeNotAllowed(string message);
    error Staking_InvalidLockupPeriod(string message);
    error Staking_InvalidStakeIndex();
    error Staking_InsufficientBalance();
    error StakeOnBehalfOfNotSupported();
    error UnstakeOnBehalfOfNotSupported();
    error Staking_MaxStakesReached();
    error Staking_InvalidBucketIndex();
    error Staking_BucketCapExceeded();

    // Events
    event StakedWithLockup(
        address indexed user,
        uint256 amount,
        uint256 lockupPeriod,
        uint256 weightedAmount
    );
    event UnstakedWithPenalty(
        address indexed user,
        uint256 unstakedAmount,
        uint256 penalty,
        uint256 returnAmount
    );
}
