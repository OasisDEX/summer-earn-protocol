// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title StakingRewardsManager
 * @notice Contract for managing staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewards interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 * @dev Inspired by Synthetix's StakingRewards contract: https://github.com/Synthetixio/synthetix/blob/v2.101.3/contracts/StakingRewards.sol
 */
import {ReentrancyGuardTransient} from "@openzeppelin-next/ReentrancyGuardTransient.sol";
import {IStakingRewardsManagerBase} from "../interfaces/IStakingRewardsManagerBase.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * @title StakingRewards
 * @notice Contract for managing staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewards interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 */
abstract contract StakingRewardsManagerBase is
    IStakingRewardsManagerBase,
    ReentrancyGuardTransient,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    struct RewardData {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 rewardsDuration;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    EnumerableMap.AddressToUintMap private _rewardTokens;
    IERC20 public stakingToken;

    mapping(IERC20 rewardToken => RewardData) public rewardData;
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardPerTokenPaid))
        public userRewardPerTokenPaid;
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardAmount))
        public rewards;

    uint256 public totalSupply;
    mapping(address account => uint256 balance) private _balances;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StakingRewards contract
     * @param _accessManager The address of the access manager
     */
    constructor(address _accessManager) ProtocolAccessManaged(_accessManager) {}

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    function rewardTokens(
        uint256 index
    ) external view override returns (IERC20) {
        if (index >= _rewardTokens.length()) revert IndexOutOfBounds();
        (address rewardTokenAddress, ) = _rewardTokens.at(index);
        return IERC20(rewardTokenAddress);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function lastTimeRewardApplicable(
        IERC20 rewardToken
    ) public view returns (uint256) {
        return
            block.timestamp < rewardData[rewardToken].periodFinish
                ? block.timestamp
                : rewardData[rewardToken].periodFinish;
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function rewardPerToken(IERC20 rewardToken) public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardData[rewardToken].rewardPerTokenStored;
        }
        return
            rewardData[rewardToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(rewardToken) -
                rewardData[rewardToken].lastUpdateTime) *
                rewardData[rewardToken].rewardRate *
                1e18) / totalSupply);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function earned(
        address account,
        IERC20 rewardToken
    ) public view returns (uint256) {
        return
            (_balances[account] *
                (rewardPerToken(rewardToken) -
                    userRewardPerTokenPaid[rewardToken][account])) /
            1e18 +
            rewards[rewardToken][account];
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function getRewardForDuration(
        IERC20 rewardToken
    ) external view returns (uint256) {
        return
            rewardData[rewardToken].rewardRate *
            rewardData[rewardToken].rewardsDuration;
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
    function stake(uint256 amount) external virtual updateReward(_msgSender()) {
        _stake(_msgSender(), _msgSender(), amount);
    }

    /// @notice Allows others to stake on behalf of a user
    /// @param receiver The account to stake for
    /// @param amount The amount of tokens to stake
    function stakeOnBehalf(
        address receiver,
        uint256 amount
    ) external virtual updateReward(receiver) {
        _stake(_msgSender(), receiver, amount);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function withdraw(uint256 amount) public virtual updateReward(msg.sender) {
        _withdraw(amount);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function getReward() public virtual nonReentrant updateReward(msg.sender) {
        uint256 rewardTokenCount = _rewardTokens.length();
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            (address rewardTokenAddress, ) = _rewardTokens.at(i);
            IERC20 rewardToken = IERC20(rewardTokenAddress);
            uint256 reward = rewards[rewardToken][msg.sender];
            if (reward > 0) {
                rewards[rewardToken][msg.sender] = 0;
                rewardToken.safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, address(rewardToken), reward);
            }
        }
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function exit() external virtual {
        getReward();
        _withdraw(_balances[msg.sender]);
    }

    /*//////////////////////////////////////////////////////////////
                            RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
    function notifyRewardAmount(
        IERC20 rewardToken,
        uint256 reward,
        uint256 newRewardsDuration
    ) external onlyGovernor updateReward(address(0)) {
        RewardData storage rewardTokenData = rewardData[rewardToken];

        // If the reward token doesn't exist, add it
        if (rewardTokenData.rewardsDuration == 0) {
            _rewardTokens.set(address(rewardToken), 0);
            rewardTokenData.rewardsDuration = newRewardsDuration > 0
                ? newRewardsDuration
                : 7 days;
            emit RewardTokenAdded(
                address(rewardToken),
                rewardTokenData.rewardsDuration
            );
        } else if (
            newRewardsDuration > 0 &&
            newRewardsDuration != rewardTokenData.rewardsDuration
        ) {
            revert CannotChangeRewardsDuration();
        }

        if (block.timestamp >= rewardTokenData.periodFinish) {
            rewardTokenData.rewardRate =
                reward /
                rewardTokenData.rewardsDuration;
        } else {
            uint256 remaining = rewardTokenData.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardTokenData.rewardRate;
            rewardTokenData.rewardRate =
                (reward + leftover) /
                rewardTokenData.rewardsDuration;
        }

        uint256 balance = rewardToken.balanceOf(address(this));
        if (
            rewardTokenData.rewardRate >
            balance / rewardTokenData.rewardsDuration
        ) revert ProvidedRewardTooHigh();

        rewardTokenData.lastUpdateTime = block.timestamp;
        rewardTokenData.periodFinish =
            block.timestamp +
            rewardTokenData.rewardsDuration;
        emit RewardAdded(address(rewardToken), reward);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function setRewardsDuration(
        IERC20 rewardToken,
        uint256 _rewardsDuration
    ) external onlyGovernor {
        RewardData storage data = rewardData[rewardToken];
        if (block.timestamp <= data.periodFinish)
            revert RewardPeriodNotComplete();
        data.rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(address(rewardToken), _rewardsDuration);
    }

    function _initialize(IERC20 _stakingToken) internal virtual {}

    /// @notice Removes a reward token from the list of reward tokens
    /// @param rewardToken The address of the reward token to remove
    function removeRewardToken(IERC20 rewardToken) external onlyGovernor {
        if (rewardData[rewardToken].rewardsDuration == 0)
            revert RewardTokenDoesNotExist();
        if (block.timestamp <= rewardData[rewardToken].periodFinish)
            revert RewardPeriodNotComplete();

        // Check if all tokens have been claimed
        uint256 remainingBalance = rewardToken.balanceOf(address(this));
        if (remainingBalance > 0)
            revert RewardTokenStillHasBalance(remainingBalance);

        // Remove the token from the rewardTokens map
        _rewardTokens.remove(address(rewardToken));

        // Reset the reward data for this token
        delete rewardData[rewardToken];

        emit RewardTokenRemoved(address(rewardToken));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _stake(address from, address account, uint256 amount) internal {
        if (amount == 0) revert CannotStakeZero();
        if (address(stakingToken) == address(0))
            revert StakingTokenNotInitialized();
        totalSupply += amount;
        _balances[account] += amount;
        stakingToken.safeTransferFrom(from, address(this), amount);
        emit Staked(account, amount);
    }

    function _withdraw(uint256 amount) internal {
        if (amount == 0) revert CannotWithdrawZero();
        totalSupply -= amount;
        _balances[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) {
        uint256 rewardTokenCount = _rewardTokens.length();
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            (address rewardTokenAddress, ) = _rewardTokens.at(i);
            IERC20 rewardToken = IERC20(rewardTokenAddress);
            RewardData storage rewardTokenData = rewardData[rewardToken];
            rewardTokenData.rewardPerTokenStored = rewardPerToken(rewardToken);
            rewardTokenData.lastUpdateTime = lastTimeRewardApplicable(
                rewardToken
            );
            if (account != address(0)) {
                rewards[rewardToken][account] = earned(account, rewardToken);
                userRewardPerTokenPaid[rewardToken][account] = rewardTokenData
                    .rewardPerTokenStored;
            }
        }
        _;
    }
}
