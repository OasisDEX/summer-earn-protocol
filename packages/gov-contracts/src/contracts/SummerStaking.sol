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

// @dev Enhanced staking contract with lockup periods and reward distribution
// @dev Users can only stake with lockup periods, rewards are calculated based on weighted stakes
contract SummerStaking is StakingRewardsManagerBase, ConfigurationManaged {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;

    // Lockup configuration
    uint256 public constant MAX_LOCKUP_PERIOD = 4 * 365 days; // 4 years
    uint256 public constant MIN_LOCKUP_PERIOD = 0; // No minimum lockup
    uint256 public constant MAX_AMOUNT_OF_STAKES = 10; // Maximum number of stakes per user

    // Weighted stake calculation constants
    uint256 private constant WEIGHTED_STAKE_BASE = 0.05e18; // 0.05 in WAD (18 decimals)
    uint256 private constant WEIGHTED_STAKE_COEFFICIENT =
        (4 * Constants.WAD) / 1e16; // 4E-16 in WAD

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
     * @param _amount The amount to stake
     * @dev Users must use stakeWithNewLockup instead
     */
    function stake(uint256 _amount) public virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithNewLockup instead");
    }

    /**
     * @notice Direct unstake function (not allowed)
     * @param _amount The amount to unstake
     * @dev Users must use unstakeFromLockup instead
     */
    function unstake(uint256 _amount) public virtual override {
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

        // Remove empty processedStake
        if (processedStake.amount == 0) {
            delete userStakes[_msgSender()][_stakeIndex];
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

        SUMMER_TOKEN.safeTransferFrom(_msgSender(), address(this), _amount);
        SUMMER_TOKEN.forceApprove(wrappedStakingToken, _amount);
        WrappedStakingToken(wrappedStakingToken).depositFor(
            address(this),
            _amount
        );

        // Mint equivalent amount of governance tokens
        _mint(_msgSender(), _amount);
        uint256 remainingTime = existingStake.lockupEndTime - block.timestamp;
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
        if (_lockupPeriod > MAX_LOCKUP_PERIOD) {
            revert Staking_InvalidLockupPeriod(
                "Lockup period cannot exceed 4 years"
            );
        }
        if (_amount == 0) revert CannotStakeZero();
        if (userStakes[_receiver].length >= MAX_AMOUNT_OF_STAKES) {
            revert Staking_MaxStakesReached();
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

        emit Staked(_from, _receiver, _amount);
        emit StakedWithLockup(
            _receiver,
            _amount,
            _lockupPeriod,
            weightedAmount
        );
    }
    /**
     * @notice Calculate the weighted stake amount based on lockup period
     * @param _amount The base amount to stake
     * @param _lockupPeriod The lockup period in seconds
     * @return The weighted stake amount for reward calculations
     * @dev Uses formula: amount * (4E-16 * time^2 + 0.05)
     */
    function calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) public view returns (uint256) {
        return _calculateWeightedStake(_amount, _lockupPeriod);
    }
    function _calculateWeightedStake(
        uint256 _amount,
        uint256 _lockupPeriod
    ) internal pure returns (uint256) {
        if (_lockupPeriod == 0) {
            // No weighting for 0 lockup
            return _amount;
        }

        // Calculate time squared (in WAD format)
        uint256 timeSquared = (_lockupPeriod * _lockupPeriod * Constants.WAD) /
            Constants.WAD;

        // Calculate multiplier: 4E-16 * time^2 + 0.05
        // 4E-16 = 4 * 10^-16 = 4e-16
        // In WAD: 4e-16 * Constants.WAD = 4e2 = 400
        uint256 multiplier = (WEIGHTED_STAKE_COEFFICIENT * timeSquared) /
            Constants.WAD +
            WEIGHTED_STAKE_BASE;

        // Apply multiplier to amount
        return (_amount * multiplier) / Constants.WAD;
    }

    /**
     * @notice Override balanceOf to return weighted stake amount for reward calculations
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
        UserStake storage userStakeInfo = userStakes[_user][_index];
        return (
            userStakeInfo.amount,
            userStakeInfo.weightedAmount,
            userStakeInfo.lockupEndTime,
            userStakeInfo.lockupPeriod
        );
    }

    /**
     * @notice Override _stake to prevent direct usage - users must use stakeWithNewLockup
     */
    function _stake(
        address from,
        address receiver,
        uint256 amount
    ) internal virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithNewLockup instead");
    }

    function _burn(uint256 _amount) internal {
        STAKED_SUMMER_TOKEN.safeTransferFrom(
            _msgSender(),
            address(this),
            _amount
        );
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).burn(_amount);
    }

    function _mint(address _user, uint256 _amount) internal {
        IStakedSummerToken(address(STAKED_SUMMER_TOKEN)).mint(_user, _amount);
    }

    /**
     * @notice Override _earned to work with weighted stakes
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
     */
    function exit() public pure override {
        revert Staking_DirectUnstakeNotAllowed("Use unstakeFromLockup instead");
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
