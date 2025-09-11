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
import {UD60x18, ud60x18, convert} from "@prb/math/src/UD60x18.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {ISummerStaking} from "../interfaces/ISummerStaking.sol";

/**
 * @title SummerStaking
 * @notice Enhanced staking contract with lockup periods, weighted rewards, and bucket management
 * @dev Users can stake with any lockup period (0-3 years), rewards calculated based on weighted stakes
 * @author Summer.fi Protocol
 */
contract SummerStaking is
    StakingRewardsManagerBase,
    ConfigurationManaged,
    ISummerStaking
{
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;

    // ============ IMMUTABLE STATE ============

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;
    WrappedStakingToken public immutable WRAPPED_SUMMER_TOKEN;

    // ============ CONSTANTS ============

    uint256 public constant MAX_LOCKUP_PERIOD = 3 * 365 days;
    uint256 public constant MAX_AMOUNT_OF_STAKES = 10;
    uint256 public constant MAX_PENALTY_PERCENTAGE = 0.2e18; // 20%

    uint256 public constant WEIGHTED_STAKE_BASE = 5e16; // 0.05 in 60.18 fixed-point
    uint256 public constant WEIGHTED_STAKE_COEFFICIENT = 350; // 3.5e-16 * 1e18 in 60.18 fixed-point

    uint256 public constant BUCKET_SHORT_TERM_MIN = 1;
    uint256 public constant BUCKET_SHORT_TERM_MAX = 90 days;
    uint256 public constant BUCKET_THREE_TO_SIX_MAX = 180 days;
    uint256 public constant BUCKET_SIX_TO_TWELVE_MAX = 365 days;
    uint256 public constant BUCKET_ONE_TO_TWO_MAX = 730 days;
    uint256 public constant BUCKET_TWO_TO_THREE_MAX = MAX_LOCKUP_PERIOD;

    // ============ STORAGE ============

    mapping(address => UserStake[]) public userStakes;
    mapping(address => uint256) public weightedBalances;
    mapping(Bucket => BucketData) public bucketData;

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

        SUMMER_TOKEN = ISummerToken(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_stakedSummerToken);
        WRAPPED_SUMMER_TOKEN = new WrappedStakingToken(_summerToken);
        stakingToken = _summerToken;

        _initializeDefaultLockupBuckets();
    }

    // ============ EXTERNAL FUNCTIONS - STAKING ============

    function stakeLockup(uint256 _amount, uint256 _lockupPeriod) external {
        _stakeWithLockup(_msgSender(), _msgSender(), _amount, _lockupPeriod);
    }

    function stakeLockupOnBehalf(
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) external {
        _stakeWithLockup(_msgSender(), _receiver, _amount, _lockupPeriod);
    }

    function addToStake(uint256 _stakeIndex, uint256 _amount) external {
        _addToStake(_msgSender(), _msgSender(), _stakeIndex, _amount);
    }

    function addToStakeOnBehalf(
        address _receiver,
        uint256 _stakeIndex,
        uint256 _amount
    ) external updateReward(_receiver) {
        _addToStake(_msgSender(), _receiver, _stakeIndex, _amount);
    }

    // ============ EXTERNAL FUNCTIONS - UNSTAKING ============

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

        uint256 unstakePenalty = calculatePenalty(
            _msgSender(),
            _amount,
            _stakeIndex
        );
        uint256 weightedAmountToRemove = (processedStake.weightedAmount *
            _amount) / processedStake.amount;

        processedStake.amount -= _amount;
        processedStake.weightedAmount -= weightedAmountToRemove;

        _updateBalancesOnUnstake(_msgSender(), _amount, weightedAmountToRemove);
        _subtractFromBucketTotal(processedStake.lockupPeriod, _amount);

        if (processedStake.amount == 0) {
            _removeStake(_msgSender(), _stakeIndex);
        } else {
            userStakes[_msgSender()][_stakeIndex] = processedStake;
        }

        _handleTokenTransfersOnUnstake(_msgSender(), _amount, unstakePenalty);

        emit UnstakedWithPenalty(
            _msgSender(),
            _amount,
            unstakePenalty,
            _amount - unstakePenalty
        );
        emit Unstaked(_msgSender(), _msgSender(), _amount);
    }

    // ============ EXTERNAL FUNCTIONS - ADMIN ============

    function updateLockupBucketCap(
        Bucket _bucket,
        uint256 _newCap
    ) external onlyGovernor {
        bucketData[_bucket].cap = _newCap;
        emit LockupBucketUpdated(_bucket, _newCap);
    }

    // ============ EXTERNAL VIEW FUNCTIONS - STAKE INFORMATION ============

    function getUserStakesCount(address _user) external view returns (uint256) {
        return userStakes[_user].length;
    }

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

    function weightedBalanceOf(
        address account
    ) public view virtual returns (uint256) {
        return weightedBalances[account];
    }

    // ============ EXTERNAL VIEW FUNCTIONS - BUCKET INFORMATION ============

    function getBucketTotalStaked(
        Bucket _bucket
    ) external view returns (uint256) {
        return bucketData[_bucket].staked;
    }

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
        buckets[5] = Bucket.TwoToThreeYears;

        for (uint256 i = 0; i < 6; i++) {
            (
                caps[i],
                stakedAmounts[i],
                minPeriods[i],
                maxPeriods[i]
            ) = _getBucketDetails(buckets[i]);
        }
    }

    // ============ EXTERNAL VIEW FUNCTIONS - PENALTY CALCULATIONS ============

    function calculatePenaltyPercentage(
        address _user,
        uint256 _stakeIndex
    ) public view returns (uint256) {
        UserStake storage userStake = userStakes[_user][_stakeIndex];

        if (block.timestamp >= userStake.lockupEndTime) {
            return 0;
        }

        uint256 timeRemaining = userStake.lockupEndTime - block.timestamp;
        return (timeRemaining * MAX_PENALTY_PERCENTAGE) / MAX_LOCKUP_PERIOD;
    }

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

    function calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) public pure returns (uint256) {
        return _calculateWeightedStake(_amount, _lockupPeriod);
    }

    // ============ PUBLIC OVERRIDE FUNCTIONS - REWARDS ============

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

    function stakeOnBehalfOf(
        address,
        uint256
    ) external pure override(IStakingRewardsManagerBase) {
        revert StakeOnBehalfOfNotSupported();
    }

    function unstakeAndWithdrawOnBehalfOf(
        address,
        uint256,
        bool
    ) external pure override(IStakingRewardsManagerBase) {
        revert UnstakeOnBehalfOfNotSupported();
    }

    function stake(
        uint256
    )
        public
        virtual
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectStakeNotAllowed("Use stakeLockup instead");
    }

    function unstake(
        uint256
    )
        public
        virtual
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeFromLockup instead");
    }

    function exit()
        public
        pure
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeFromLockup instead");
    }

    // ============ INTERNAL FUNCTIONS - STAKING LOGIC ============

    function _stakeWithLockup(
        address _from,
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal updateReward(_receiver) {
        if (_receiver == address(0)) revert CannotStakeToZeroAddress();
        if (_from == address(0)) revert CannotStakeToZeroAddress();
        if (_amount == 0) revert CannotStakeZero();
        if (_lockupPeriod > MAX_LOCKUP_PERIOD) {
            revert Staking_InvalidLockupPeriod(
                "Lockup period cannot exceed 3 years"
            );
        }
        if (userStakes[_receiver].length >= MAX_AMOUNT_OF_STAKES) {
            revert Staking_MaxStakesReached();
        }
        if (_wouldExceedBucketCap(_lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            _lockupPeriod
        );

        userStakes[_receiver].push(
            UserStake({
                amount: _amount,
                weightedAmount: weightedAmount,
                lockupEndTime: block.timestamp + _lockupPeriod,
                lockupPeriod: _lockupPeriod
            })
        );

        _updateBalancesOnStake(_receiver, _amount, weightedAmount);
        _addToBucketTotal(_lockupPeriod, _amount);
        _handleTokenTransfersOnStake(_from, _receiver, _amount);

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _amount,
            _lockupPeriod,
            weightedAmount
        );
    }

    function _addToStake(
        address _from,
        address _receiver,
        uint256 _stakeIndex,
        uint256 _amount
    ) internal updateReward(_receiver) {
        if (_amount == 0) revert CannotStakeZero();
        if (_stakeIndex >= userStakes[_receiver].length)
            revert Staking_InvalidStakeIndex();

        UserStake memory processedStake = userStakes[_receiver][_stakeIndex];
        if (processedStake.amount == 0) revert Staking_InvalidStakeIndex();
        if (processedStake.lockupEndTime < block.timestamp) {
            revert Staking_InvalidLockupPeriod("Lockup period has ended");
        }
        if (_wouldExceedBucketCap(processedStake.lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        uint256 remainingTime = processedStake.lockupEndTime - block.timestamp;
        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            remainingTime
        );

        processedStake.amount += _amount;
        processedStake.weightedAmount += weightedAmount;

        userStakes[_receiver][_stakeIndex] = processedStake;
        _updateBalancesOnStake(_receiver, _amount, weightedAmount);
        _addToBucketTotal(processedStake.lockupPeriod, _amount);
        _handleTokenTransfersOnStake(_from, _receiver, _amount);

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _amount,
            remainingTime,
            weightedAmount
        );
    }

    function _stake(address, address, uint256) internal virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeLockup instead");
    }

    // ============ INTERNAL FUNCTIONS - BUCKET MANAGEMENT ============

    function _initializeDefaultLockupBuckets() internal {
        bucketData[Bucket.NoLockup] = BucketData({
            cap: type(uint256).max,
            staked: 0
        });
        bucketData[Bucket.ShortTerm] = BucketData({cap: 0, staked: 0});
        bucketData[Bucket.ThreeToSixMonths] = BucketData({
            cap: type(uint256).max,
            staked: 0
        });
        bucketData[Bucket.SixToTwelveMonths] = BucketData({
            cap: type(uint256).max,
            staked: 0
        });
        bucketData[Bucket.OneToTwoYears] = BucketData({
            cap: type(uint256).max,
            staked: 0
        });
        bucketData[Bucket.TwoToThreeYears] = BucketData({
            cap: type(uint256).max,
            staked: 0
        });
    }

    function _findBucket(uint256 _lockupPeriod) internal pure returns (Bucket) {
        if (_lockupPeriod == 0) return Bucket.NoLockup;
        if (_lockupPeriod <= BUCKET_SHORT_TERM_MAX) return Bucket.ShortTerm;
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

    function _addToBucketTotal(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        Bucket bucket = _findBucket(_lockupPeriod);
        bucketData[bucket].staked += _amount;
    }

    function _subtractFromBucketTotal(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal {
        Bucket bucket = _findBucket(_lockupPeriod);
        bucketData[bucket].staked -= _amount;
    }

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
        } else if (_bucket == Bucket.ThreeToSixMonths) {
            minLockupPeriod = BUCKET_SHORT_TERM_MAX + 1;
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

    function _wouldExceedBucketCap(
        uint256 _lockupPeriod,
        uint256 _amount
    ) internal view returns (bool) {
        Bucket bucket = _findBucket(_lockupPeriod);
        uint256 currentBucketTotal = bucketData[bucket].staked;
        uint256 bucketCap = bucketData[bucket].cap;
        return (currentBucketTotal + _amount) > bucketCap;
    }

    // ============ INTERNAL FUNCTIONS - WEIGHTED STAKE CALCULATIONS ============

    function _calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal pure returns (uint256) {
        UD60x18 time = convert(_lockupPeriod);
        UD60x18 timeSquared = time.mul(time);

        UD60x18 multiplier = ud60x18(WEIGHTED_STAKE_COEFFICIENT)
            .mul(timeSquared)
            .add(ud60x18(WEIGHTED_STAKE_BASE));

        return ud60x18(_amount).mul(multiplier).unwrap();
    }

    // ============ INTERNAL FUNCTIONS - TOKEN TRANSFERS ============

    function _handleTokenTransfersOnStake(
        address from,
        address to,
        uint amount
    ) internal {
        SUMMER_TOKEN.safeTransferFrom(from, address(this), amount);
        SUMMER_TOKEN.forceApprove(address(WRAPPED_SUMMER_TOKEN), amount);
        WRAPPED_SUMMER_TOKEN.depositFor(address(this), amount);
        STAKED_SUMMER_TOKEN.mint(to, amount);
    }

    function _handleTokenTransfersOnUnstake(
        address from,
        uint amount,
        uint unstakePenalty
    ) internal {
        if (unstakePenalty > 0) {
            WRAPPED_SUMMER_TOKEN.withdrawTo(address(this), amount);
            SUMMER_TOKEN.safeTransfer(from, amount - unstakePenalty);
            SUMMER_TOKEN.safeTransfer(treasury(), unstakePenalty);
        } else {
            WRAPPED_SUMMER_TOKEN.withdrawTo(from, amount);
        }

        STAKED_SUMMER_TOKEN.safeTransferFrom(from, address(this), amount);
        STAKED_SUMMER_TOKEN.burn(amount);
    }

    // ============ INTERNAL FUNCTIONS - BALANCE MANAGEMENT ============

    function _updateBalancesOnStake(
        address _receiver,
        uint256 _amount,
        uint256 _weightedAmount
    ) internal {
        _balances[_receiver] += _amount;
        weightedBalances[_receiver] += _weightedAmount;
        totalSupply += _weightedAmount;
    }

    function _updateBalancesOnUnstake(
        address _receiver,
        uint256 _amount,
        uint256 _weightedAmount
    ) internal {
        _balances[_receiver] -= _amount;
        weightedBalances[_receiver] -= _weightedAmount;
        totalSupply -= _weightedAmount;
    }

    function _removeStake(address _user, uint256 _index) internal {
        UserStake[] storage stakes = userStakes[_user];
        if (_index >= stakes.length) return;
        stakes[_index] = stakes[stakes.length - 1];
        stakes.pop();
    }
}
