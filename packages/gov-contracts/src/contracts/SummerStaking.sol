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
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

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
    using SafeERC20 for IERC20;

    // ============ IMMUTABLE STATE ============

    ISummerToken public immutable SUMMER_TOKEN;
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

    mapping(uint256 portfolioId => UserStake[] stakes)
        public stakesByPortfolioId;
    // id ID for user's stakes; 0 = no stakes
    mapping(address owner => uint256 portfolioId) public stakePortfolioId;
    uint256 private _nextPortfolioId = 1;

    mapping(address => uint256) public weightedBalances;
    mapping(Bucket => BucketData) public bucketData;
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

        SUMMER_TOKEN = ISummerToken(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_stakedSummerToken);
        WRAPPED_SUMMER_TOKEN = new WrappedStakingToken(_summerToken);
        stakingToken = _summerToken;

        _initializeDefaultLockupBuckets();
    }

    // ============ INTERNAL - ID HELPERS ============

    /**
     * @notice Get the portfolio id for a given owner address
     * @param owner The address to get the id for
     * @return The portfolio id for the address
     */
    function _getPortfolioId(address owner) internal view returns (uint256) {
        return stakePortfolioId[owner];
    }

    /**
     * @notice Ensure a portfolio id for a given owner address
     * @param owner The address to ensure an id for
     * @return The portfolio id for the address
     */
    function _ensurePortfolioId(address owner) internal returns (uint256) {
        if (stakePortfolioId[owner] == 0) {
            uint256 _stakePortfolioId = _nextPortfolioId++;
            stakePortfolioId[owner] = _stakePortfolioId;
            stakesByPortfolioId[_stakePortfolioId].push(
                UserStake({
                    amount: 0,
                    weightedAmount: 0,
                    lockupEndTime: block.timestamp,
                    lockupPeriod: 0
                })
            );
        }
        return stakePortfolioId[owner];
    }

    // ============ EXTERNAL FUNCTIONS - STAKING ============

    /// @inheritdoc ISummerStaking
    function stakeLockup(
        uint256 _amount,
        uint256 _lockupPeriod
    ) external nonReentrant {
        _stakeLockup(_msgSender(), _msgSender(), _amount, _lockupPeriod);
    }

    /// @inheritdoc ISummerStaking
    function stakeLockupOnBehalf(
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) external nonReentrant {
        _stakeLockup(_msgSender(), _receiver, _amount, _lockupPeriod);
    }

    /// @inheritdoc ISummerStaking
    function transferStakes(
        address _to
    ) external updateReward(_msgSender()) nonReentrant {
        address from = _msgSender();
        if (_to == address(0))
            revert Staking_InvalidAddress("Target address cannot be zero");
        if (from == _to)
            revert Staking_InvalidAddress("Cannot move stakes to self");

        if (stakesByPortfolioId[_getPortfolioId(_to)].length != 0)
            revert Staking_ExistingTarget("Target already has stakes");

        UserStake[] storage fromStakes = stakesByPortfolioId[
            _getPortfolioId(from)
        ];
        uint256 stakeCount = fromStakes.length;
        if (stakeCount == 0) revert Staking_InvalidStakeIndex();

        uint256 rewardTokenCount = EnumerableSet.length(_rewardTokensList);
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardTokenAddress = EnumerableSet.at(_rewardTokensList, i);
            if (userRewardPerTokenPaid[rewardTokenAddress][_to] != 0)
                revert Staking_ExistingTarget("Target already has rewards");
            uint256 fromReward = rewards[rewardTokenAddress][from];
            if (fromReward != 0) {
                rewards[rewardTokenAddress][from] = 0;
                rewards[rewardTokenAddress][_to] = fromReward;
            }
            // Align paid markers to current snapshot for correctness going forward
            userRewardPerTokenPaid[rewardTokenAddress][from] = rewardData[
                rewardTokenAddress
            ].rewardPerTokenStored;
            userRewardPerTokenPaid[rewardTokenAddress][_to] = rewardData[
                rewardTokenAddress
            ].rewardPerTokenStored;
        }

        // Ensure target doesn't hold xSUMR and move xSUMR from from -> to
        if (STAKED_SUMMER_TOKEN.balanceOf(_to) != 0) {
            revert Staking_ExistingTarget("Target already holds xSUMR");
        }
        uint256 xsumrToMove = _balances[from];
        if (xsumrToMove != 0) {
            STAKED_SUMMER_TOKEN.burnFrom(from, xsumrToMove);
            STAKED_SUMMER_TOKEN.mint(_to, xsumrToMove);
        }

        stakePortfolioId[_to] = _getPortfolioId(from);
        stakePortfolioId[from] = 0;

        // Move accounting balances
        uint256 fromAmount = _balances[from];
        uint256 fromWeighted = weightedBalances[from];

        _balances[from] = 0;
        weightedBalances[from] = 0;

        _balances[_to] += fromAmount;
        weightedBalances[_to] += fromWeighted;

        // Rewards debt already updated via updateReward modifiers
        // Emit generic events for visibility
        emit StakesTransferred(from, _to, stakePortfolioId[_to]);
    }

    // ============ EXTERNAL FUNCTIONS - UNSTAKING ============

    function unstakeLockup(
        uint256 _stakeIndex,
        uint256 _amount
    ) public virtual updateReward(_msgSender()) nonReentrant {
        if (_amount == 0) revert Staking_InvalidAmount("Amount cannot be zero");
        if (_amount > _balances[_msgSender()])
            revert Staking_InsufficientBalance();
        uint256 _stakePortfolioId = _getPortfolioId(_msgSender());
        UserStake[] storage stakes = stakesByPortfolioId[_stakePortfolioId];
        if (_stakeIndex >= stakes.length) revert Staking_InvalidStakeIndex();

        UserStake memory processedStake = stakes[_stakeIndex];
        if (processedStake.amount < _amount) revert Staking_InvalidStakeIndex();

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

        if (processedStake.amount == 0 && !_isNoLockupStakeIndex(_stakeIndex)) {
            _removeStake(_msgSender(), _stakeIndex);
        } else {
            stakes[_stakeIndex] = processedStake;
        }

        _handleTokenTransfersOnUnstake(_msgSender(), _amount, unstakePenalty);

        emit UnstakedWithPenalty(
            _msgSender(),
            _stakePortfolioId,
            _stakeIndex,
            _amount,
            unstakePenalty,
            _amount - unstakePenalty
        );
        emit Unstaked(_msgSender(), _msgSender(), _amount);
    }

    // ============ EXTERNAL FUNCTIONS - ADMIN ============
    /// @inheritdoc ISummerStaking
    function updateLockupBucketCap(
        Bucket _bucket,
        uint256 _newCap
    ) external onlyGovernor {
        bucketData[_bucket].cap = _newCap;
        emit LockupBucketUpdated(_bucket, _newCap);
    }

    /// @inheritdoc ISummerStaking
    function updatePenaltyEnabled(bool _penaltyEnabled) external onlyGovernor {
        penaltyEnabled = _penaltyEnabled;
        emit PenaltyEnabledUpdated(_penaltyEnabled);
    }

    /// @inheritdoc ISummerStaking
    function rescueToken(address _token, address _to) external onlyGovernor {
        if (_token == address(WRAPPED_SUMMER_TOKEN)) {
            revert Staking_InvalidAddress("Cannot rescue wrapped summer token");
        }
        IERC20(_token).safeTransfer(
            _to,
            IERC20(_token).balanceOf(address(this))
        );
    }

    // ============ EXTERNAL VIEW FUNCTIONS - STAKE INFORMATION ============

    function getUserStakesCount(address _user) external view returns (uint256) {
        return stakesByPortfolioId[_getPortfolioId(_user)].length;
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
        uint256 portfolioId = _getPortfolioId(_user);
        UserStake[] storage stakes = stakesByPortfolioId[portfolioId];
        if (_index < stakes.length) {
            amount = stakes[_index].amount;
            weightedAmount = stakes[_index].weightedAmount;
            lockupEndTime = stakes[_index].lockupEndTime;
            lockupPeriod = stakes[_index].lockupPeriod;
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
        if (!penaltyEnabled) {
            return 0;
        }
        UserStake storage userStake = stakesByPortfolioId[
            _getPortfolioId(_user)
        ][_stakeIndex];

        if (block.timestamp >= userStake.lockupEndTime) {
            return 0;
        }

        uint256 timeRemaining = userStake.lockupEndTime - block.timestamp;
        if (timeRemaining < FIXED_PENALTY_PERIOD) {
            return MIN_PENALTY_PERCENTAGE;
        }
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
        revert Staking_DirectUnstakeNotAllowed("Use unstakeLockup instead");
    }

    function exit()
        public
        pure
        override(StakingRewardsManagerBase, IStakingRewardsManagerBase)
    {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeLockup instead");
    }

    // ============ INTERNAL FUNCTIONS - STAKING LOGIC ============

    function _stakeLockup(
        address _from,
        address _receiver,
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal updateReward(_receiver) {
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
        if (
            stakesByPortfolioId[_getPortfolioId(_receiver)].length >=
            MAX_AMOUNT_OF_STAKES
        ) {
            revert Staking_MaxStakesReached();
        }
        if (_wouldExceedBucketCap(_lockupPeriod, _amount)) {
            revert Staking_BucketCapExceeded();
        }

        uint256 weightedAmount = _calculateWeightedStake(
            _amount,
            _lockupPeriod
        );
        uint256 _stakePortfolioId = _ensurePortfolioId(_receiver);

        uint256 _stakeIndex;
        if (_lockupPeriod == 0) {
            UserStake storage noLockupStake = _noLockupStake(_stakePortfolioId);
            noLockupStake.amount += _amount;
            noLockupStake.weightedAmount += weightedAmount;
            noLockupStake.lockupEndTime = block.timestamp;
            _stakeIndex = NO_LOCKUP_INDEX;
        } else {
            stakesByPortfolioId[_stakePortfolioId].push(
                UserStake({
                    amount: _amount,
                    weightedAmount: weightedAmount,
                    lockupEndTime: block.timestamp + _lockupPeriod,
                    lockupPeriod: _lockupPeriod
                })
            );
            _stakeIndex = stakesByPortfolioId[_stakePortfolioId].length - 1;
        }
        _updateBalancesOnStake(_receiver, _amount, weightedAmount);
        _addToBucketTotal(_lockupPeriod, _amount);
        _handleTokenTransfersOnStake(_from, _receiver, _amount);

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _stakePortfolioId,
            _stakeIndex,
            _amount,
            _lockupPeriod,
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

        STAKED_SUMMER_TOKEN.burnFrom(from, amount);
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
        UserStake[] storage stakes = stakesByPortfolioId[
            _getPortfolioId(_user)
        ];
        if (_index >= stakes.length) return;
        stakes[_index] = stakes[stakes.length - 1];
        stakes.pop();
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
     * @notice Get the no lockup stake for a given portfolio id
     * @param portfolioId The portfolio id to get the no lockup stake for
     * @return The no lockup stake for the portfolio id
     */
    function _noLockupStake(
        uint256 portfolioId
    ) internal view returns (UserStake storage) {
        return stakesByPortfolioId[portfolioId][NO_LOCKUP_INDEX];
    }
}
