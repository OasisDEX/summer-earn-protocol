// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakedSummerToken} from "../interfaces/IStakedSummerToken.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {WrappedStakingToken} from "./WrappedStakingToken.sol";

// @dev Enhanced staking contract with lockup periods and reward distribution
// @dev Users can only stake with lockup periods, rewards are calculated based on weighted stakes
contract SummerStaking is StakingRewardsManagerBase {
    using SafeERC20 for IStakedSummerToken;
    using SafeERC20 for ISummerToken;

    ISummerToken public immutable SUMMER_TOKEN;
    IStakedSummerToken public immutable STAKED_SUMMER_TOKEN;

    // Lockup configuration
    uint256 public constant MAX_LOCKUP_PERIOD = 4 * 365 days; // 4 years
    uint256 public constant MIN_LOCKUP_PERIOD = 0; // No minimum lockup

    // Weighted stake calculation constants
    uint256 private constant WEIGHTED_STAKE_BASE = 0.05e18; // 0.05 in WAD (18 decimals)
    uint256 private constant WEIGHTED_STAKE_COEFFICIENT = 4e-16 * 1e18; // 4E-16 in WAD

    // User stake information with lockup details
    struct UserStake {
        uint256 amount;        // Actual staked amount
        uint256 weightedAmount; // Weighted amount for reward calculations
        uint256 lockupEndTime; // Timestamp when lockup ends
        uint256 lockupPeriod;  // Original lockup period in seconds
    }

    // Mapping: user => their stakes (multiple stakes allowed)
    mapping(address => UserStake[]) public userStakes;

    // Mapping: user => total actual staked amount
    mapping(address => uint256) public userTotalStaked;

    // Mapping: user => total weighted staked amount
    mapping(address => uint256) public userTotalWeightedStaked;

    // Wrapped version of staking token for internal accounting
    address public immutable wrappedStakingToken;

    constructor(
        address _protocolAccessManager,
        address _summerToken,
        address _xSumr
    ) StakingRewardsManagerBase(_protocolAccessManager) {
        if (_summerToken == address(0)) {
            revert Staking_InvalidAddress(
                "Summer token address cannot be zero"
            );
        }
        if (_xSumr == address(0)) {
            revert Staking_InvalidAddress(
                "StakedSummerToken address cannot be zero"
            );
        }

        SUMMER_TOKEN = ISummerToken(_summerToken);
        STAKED_SUMMER_TOKEN = IStakedSummerToken(_xSumr);

        // Create wrapped version of staking token for internal accounting
        wrappedStakingToken = address(new WrappedStakingToken(_summerToken));

        // Set the staking token for StakingRewardsManagerBase
        stakingToken = _summerToken;
    }



    function stakeOnBehalfOf(address, uint256) external pure override {
        revert StakeOnBehalfOfNotSupported();
    }

    /**
     * @notice No op function to satisfy interface requirements. Emits an event but performs no state changes.
     * @dev This operation is not supported and will only emit an event
     */
    function unstakeAndWithdrawOnBehalfOf(
        address,
        uint256,
        bool
    ) external pure override {
        revert UnstakeOnBehalfOfNotSupported();
    }

    // Override stake to prevent direct usage - users must use stakeWithLockup
    function stake(uint256 _amount) public virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithLockup instead");
    }

    // Override unstake to handle proportional unstaking with lockup penalties
    function unstake(uint256 _amount) public virtual override {
        if (_amount == 0) revert CannotUnstakeZero();
        if (_amount > userTotalStaked[_msgSender()]) revert Staking_InsufficientBalance();

        uint256 remainingToUnstake = _amount;
        UserStake[] storage stakes = userStakes[_msgSender()];
        uint256 totalPenalty = 0;
        uint256 totalReturnAmount = 0;

        // Unstake proportionally from all stakes
        for (uint256 i = 0; i < stakes.length && remainingToUnstake > 0; i++) {
            UserStake storage currentStake = stakes[i];
            if (currentStake.amount == 0) continue;

            uint256 amountFromThisStake = (currentStake.amount * remainingToUnstake) / userTotalStaked[_msgSender()];
            if (amountFromThisStake > currentStake.amount) {
                amountFromThisStake = currentStake.amount;
            }

            if (amountFromThisStake > 0) {
                // Calculate penalty for this stake
                uint256 stakePenalty = 0;
                if (block.timestamp < currentStake.lockupEndTime) {
                    stakePenalty = calculatePenalty(_msgSender(), i);
                    stakePenalty = (stakePenalty * amountFromThisStake) / currentStake.amount;
                }

                // Update stake
                uint256 weightedAmountToRemove = (currentStake.weightedAmount * amountFromThisStake) / currentStake.amount;
                currentStake.amount -= amountFromThisStake;
                currentStake.weightedAmount -= weightedAmountToRemove;

                // Update totals
                userTotalStaked[_msgSender()] -= amountFromThisStake;
                userTotalWeightedStaked[_msgSender()] -= weightedAmountToRemove;
                totalSupply -= weightedAmountToRemove;

                // Accumulate penalties and return amounts
                totalPenalty += stakePenalty;
                totalReturnAmount += (amountFromThisStake - stakePenalty);

                remainingToUnstake -= amountFromThisStake;

                // Remove empty stake
                if (currentStake.amount == 0) {
                    _removeStake(_msgSender(), i);
                    i--; // Adjust index after removal
                }
            }
        }

        // Burn staked tokens and return SUMMER tokens from wrapped token
        _burn(_amount);
        if (totalReturnAmount > 0) {
            WrappedStakingToken(wrappedStakingToken).withdrawTo(_msgSender(), totalReturnAmount);
        }

        emit UnstakedWithPenalty(_msgSender(), _amount, totalPenalty, totalReturnAmount);
    }

    /**
     * @notice Stake tokens with a lockup period
     * @param _amount The amount of SUMMER tokens to stake
     * @param _lockupPeriod The lockup period in seconds (0 to 4 years)
     */
    function stakeWithLockup(uint256 _amount, uint256 _lockupPeriod) external updateReward(_msgSender()) {
        if (_amount == 0) revert CannotStakeZero();
        if (_lockupPeriod > MAX_LOCKUP_PERIOD) {
            revert Staking_InvalidLockupPeriod("Lockup period cannot exceed 4 years");
        }

        // Use the wrapped token approach for staking
        _stakeWithLockup(_msgSender(), _msgSender(), _amount, _lockupPeriod);
    }

    /**
     * @notice Internal function to stake with lockup
     * @param _from The address to transfer tokens from
     * @param _receiver The address to receive the stake
     * @param _amount The amount of SUMMER tokens to stake
     * @param _lockupPeriod The lockup period in seconds
     */
    function _stakeWithLockup(address _from, address _receiver, uint256 _amount, uint256 _lockupPeriod) internal {
        // Transfer SUMMER tokens from user to contract and wrap them
        SUMMER_TOKEN.safeTransferFrom(_from, address(this), _amount);
        SUMMER_TOKEN.forceApprove(wrappedStakingToken, _amount);
        WrappedStakingToken(wrappedStakingToken).depositFor(address(this), _amount);

        // Mint equivalent amount of staked tokens
        _mint(_receiver, _amount);

        // Calculate weighted amount based on lockup period
        uint256 weightedAmount = _calculateWeightedStake(_amount, _lockupPeriod);

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
        userTotalStaked[_receiver] += _amount;
        userTotalWeightedStaked[_receiver] += weightedAmount;

        // Update global totals (weighted amount for reward calculations)
        totalSupply += weightedAmount;

        emit StakedWithLockup(_receiver, _amount, _lockupPeriod, weightedAmount);
    }

    /**
     * @notice Calculate weighted stake amount based on lockup period
     * @param _amount The actual stake amount
     * @param _lockupPeriod The lockup period in seconds
     * @return The weighted stake amount
     * @dev Formula: amount * (4E-16 * time^2 + 0.05)
     */
    function calculateWeightedStake(uint256 _amount, uint256 _lockupPeriod) external pure returns (uint256) {
        return _calculateWeightedStake(_amount, _lockupPeriod);
    }

    function _calculateWeightedStake(uint256 _amount, uint256 _lockupPeriod) internal pure returns (uint256) {
        if (_lockupPeriod == 0) {
            // No weighting for 0 lockup
            return _amount;
        }

        // Calculate time squared (in WAD format)
        uint256 timeSquared = (_lockupPeriod * _lockupPeriod * 1e18) / 1e18;

        // Calculate multiplier: 4E-16 * time^2 + 0.05
        // 4E-16 = 4 * 10^-16 = 4e-16
        // In WAD: 4e-16 * 1e18 = 4e2 = 400
        uint256 multiplier = (WEIGHTED_STAKE_COEFFICIENT * timeSquared) / 1e18 + WEIGHTED_STAKE_BASE;

        // Apply multiplier to amount
        return (_amount * multiplier) / 1e18;
    }

    /**
     * @notice Override balanceOf to return weighted stake amount for reward calculations
     * @param account The address to check balance for
     * @return The weighted stake balance
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return userTotalWeightedStaked[account];
    }

    /**
     * @notice Get the actual staked amount (not weighted) for a user
     * @param account The address to check balance for
     * @return The actual staked amount
     */
    function actualBalanceOf(address account) external view returns (uint256) {
        return userTotalStaked[account];
    }

    /**
     * @notice Calculate penalty for early unstaking
     * @param _stakeIndex The index of the stake to calculate penalty for
     * @return The penalty amount
     * @dev Penalty is proportional to time remaining in lockup period
     */
    function calculatePenalty(address _user, uint256 _stakeIndex) public view returns (uint256) {
        UserStake storage userStake = userStakes[_user][_stakeIndex];

        if (block.timestamp >= userStake.lockupEndTime) {
            return 0; // No penalty if lockup period has ended
        }

        uint256 timeRemaining = userStake.lockupEndTime - block.timestamp;
        uint256 penaltyPercentage = (timeRemaining * 1e18) / userStake.lockupPeriod;

        // Penalty is proportional to weighted amount and time remaining
        return (userStake.weightedAmount * penaltyPercentage) / 1e18;
    }

    /**
     * @notice Unstake tokens from specific stake index
     * @param _stakeIndex The index of the stake to unstake from
     * @param _amount The amount to unstake
     */
    function unstakeFromStake(uint256 _stakeIndex, uint256 _amount) external updateReward(_msgSender()) {
        if (_amount == 0) revert CannotUnstakeZero();

        UserStake storage userStake = userStakes[_msgSender()][_stakeIndex];
        if (userStake.amount == 0) revert Staking_InvalidStakeIndex();

        uint256 actualAmountToUnstake = _amount;
        if (_amount > userStake.amount) {
            actualAmountToUnstake = userStake.amount;
        }

        // Calculate penalty if unstaking before lockup ends
        uint256 penalty = 0;
        if (block.timestamp < userStake.lockupEndTime) {
            penalty = calculatePenalty(_msgSender(), _stakeIndex);
            // Scale penalty proportionally to the amount being unstaked
            penalty = (penalty * actualAmountToUnstake) / userStake.amount;
        }

        // Calculate weighted amount to remove
        uint256 weightedAmountToRemove = (userStake.weightedAmount * actualAmountToUnstake) / userStake.amount;

        // Update stake amounts
        userStake.amount -= actualAmountToUnstake;
        userStake.weightedAmount -= weightedAmountToRemove;

        // Update user's total amounts
        userTotalStaked[_msgSender()] -= actualAmountToUnstake;
        userTotalWeightedStaked[_msgSender()] -= weightedAmountToRemove;

        // Update global total supply
        totalSupply -= weightedAmountToRemove;

        // Burn staked tokens
        _burn(actualAmountToUnstake);

        // Return SUMMER tokens minus penalty by withdrawing from wrapped token
        uint256 returnAmount = actualAmountToUnstake - penalty;
        if (returnAmount > 0) {
            WrappedStakingToken(wrappedStakingToken).withdrawTo(_msgSender(), returnAmount);
        }

        // If stake is fully unstaked, remove it from array
        if (userStake.amount == 0) {
            _removeStake(_msgSender(), _stakeIndex);
        }

        emit UnstakedWithPenalty(_msgSender(), actualAmountToUnstake, penalty, returnAmount);
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
    function getUserStake(address _user, uint256 _index) external view returns (
        uint256 amount,
        uint256 weightedAmount,
        uint256 lockupEndTime,
        uint256 lockupPeriod
    ) {
        UserStake storage userStakeInfo = userStakes[_user][_index];
        return (userStakeInfo.amount, userStakeInfo.weightedAmount, userStakeInfo.lockupEndTime, userStakeInfo.lockupPeriod);
    }

    /**
     * @notice Override _stake to prevent direct usage - users must use stakeWithLockup
     */
    function _stake(address from, address receiver, uint256 amount) internal virtual override {
        revert Staking_DirectStakeNotAllowed("Use stakeWithLockup instead");
    }

    /**
     * @notice Override _unstake to work with wrapped tokens
     */
    function _unstake(address from, address receiver, uint256 amount) internal virtual override {
        if (amount == 0) revert CannotUnstakeZero();

        totalSupply -= amount;
        _balances[from] -= amount;

        // Withdraw from wrapped token directly to receiver
        WrappedStakingToken(wrappedStakingToken).withdrawTo(receiver, amount);

        emit Unstaked(from, receiver, amount);
    }

    function _burn(uint256 _amount) internal {
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
    function _earned(address account, address rewardToken) internal view override returns (uint256) {
        uint256 weightedBalance = userTotalWeightedStaked[account];
        if (weightedBalance == 0) {
            return rewards[rewardToken][account];
        }

        return
            (weightedBalance *
                (rewardPerToken(rewardToken) -
                    userRewardPerTokenPaid[rewardToken][account])) /
            1e18 +
            rewards[rewardToken][account];
    }

    // Custom errors
    error Staking_InvalidAddress(string message);
    error Staking_InvalidOwner(string message);
    error Staking_InvalidIndex();
    error Staking_DuplicateFactory();
    error Staking_FactoryNotFound();
    error Staking_InvalidBalance();
    error Staking_VestingWalletsEmpty();
    error Staking_NoVestingWalletsStaked();
    error Staking_DirectStakeNotAllowed(string message);
    error Staking_DirectUnstakeNotAllowed(string message);
    error Staking_InvalidLockupPeriod(string message);
    error Staking_InvalidStakeIndex();
    error Staking_InsufficientBalance();
    error StakeOnBehalfOfNotSupported();
    error UnstakeOnBehalfOfNotSupported();

    // Events
    event VestingFactoryAdded(address indexed vestingFactory);
    event VestingFactoryRemoved(address indexed vestingFactory);
    event StakedWithLockup(address indexed user, uint256 amount, uint256 lockupPeriod, uint256 weightedAmount);
    event UnstakedWithPenalty(address indexed user, uint256 unstakedAmount, uint256 penalty, uint256 returnAmount);
}




