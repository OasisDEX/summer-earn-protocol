// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ReentrancyGuardTransient} from "@openzeppelin-next/ReentrancyGuardTransient.sol";
import {IStakingRewardsManager} from "../interfaces/IStakingRewardsManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title StakingRewards
 * @notice Contract for managing staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewards interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 */
contract StakingRewardsManager is
    IStakingRewardsManager,
    ReentrancyGuardTransient,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;

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

    IERC20[] public rewardsTokens;
    IERC20 public stakingToken;

    mapping(IERC20 rewardToken => RewardData) public rewardData;
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardPerTokenPaid))
        public userRewardPerTokenPaid;
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardAmount))
        public rewards;

    uint256 private _totalSupply;
    mapping(address account => uint256 balance) private _balances;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the StakingRewards contract
     * @param params Struct containing initialization parameters
     */
    constructor(
        StakingRewardsParams memory params
    ) ProtocolAccessManaged(params.accessManager) {
        if (params.rewardsTokens.length == 0) revert NoRewardTokens();
        for (uint256 i = 0; i < params.rewardsTokens.length; i++) {
            rewardsTokens.push(IERC20(params.rewardsTokens[i]));
            rewardData[IERC20(params.rewardsTokens[i])]
                .rewardsDuration = 7 days;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManager
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IStakingRewardsManager
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IStakingRewardsManager
    function lastTimeRewardApplicable(
        IERC20 rewardToken
    ) public view returns (uint256) {
        return
            block.timestamp < rewardData[rewardToken].periodFinish
                ? block.timestamp
                : rewardData[rewardToken].periodFinish;
    }

    /// @inheritdoc IStakingRewardsManager
    function rewardPerToken(IERC20 rewardToken) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[rewardToken].rewardPerTokenStored;
        }
        return
            rewardData[rewardToken].rewardPerTokenStored +
            (((lastTimeRewardApplicable(rewardToken) -
                rewardData[rewardToken].lastUpdateTime) *
                rewardData[rewardToken].rewardRate *
                1e18) / _totalSupply);
    }

    /// @inheritdoc IStakingRewardsManager
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

    /// @inheritdoc IStakingRewardsManager
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

    /// @inheritdoc IStakingRewardsManager
    function stake(
        address account,
        uint256 amount
    ) external virtual updateReward(account) {
        _stake(account, amount);
    }

    /// @inheritdoc IStakingRewardsManager
    function withdraw(uint256 amount) public virtual updateReward(msg.sender) {
        _withdraw(amount);
    }

    /// @inheritdoc IStakingRewardsManager
    function getReward() public virtual nonReentrant updateReward(msg.sender) {
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            IERC20 rewardToken = rewardsTokens[i];
            uint256 reward = rewards[rewardToken][msg.sender];
            if (reward > 0) {
                rewards[rewardToken][msg.sender] = 0;
                rewardToken.safeTransfer(msg.sender, reward);
                emit RewardPaid(msg.sender, address(rewardToken), reward);
            }
        }
    }

    /// @inheritdoc IStakingRewardsManager
    function exit() external virtual {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /*//////////////////////////////////////////////////////////////
                            RESTRICTED FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManager
    function notifyRewardAmount(
        IERC20 rewardToken,
        uint256 reward
    ) external onlyGovernor updateReward(address(0)) {
        RewardData storage data = rewardData[rewardToken];
        if (data.rewardsDuration == 0) revert RewardTokenNotInitialized();

        if (block.timestamp >= data.periodFinish) {
            data.rewardRate = reward / data.rewardsDuration;
        } else {
            uint256 remaining = data.periodFinish - block.timestamp;
            uint256 leftover = remaining * data.rewardRate;
            data.rewardRate = (reward + leftover) / data.rewardsDuration;
        }

        uint256 balance = rewardToken.balanceOf(address(this));
        if (data.rewardRate > balance / data.rewardsDuration)
            revert ProvidedRewardTooHigh();

        data.lastUpdateTime = block.timestamp;
        data.periodFinish = block.timestamp + data.rewardsDuration;
        emit RewardAdded(address(rewardToken), reward);
    }

    /// @inheritdoc IStakingRewardsManager
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

    /// @inheritdoc IStakingRewardsManager
    function addRewardToken(
        IERC20 rewardToken,
        uint256 rewardsDuration
    ) external onlyGovernor {
        if (rewardData[rewardToken].rewardsDuration != 0)
            revert RewardTokenAlreadyExists();
        if (rewardsDuration == 0) revert InvalidRewardsDuration();
        rewardsTokens.push(rewardToken);
        rewardData[rewardToken].rewardsDuration = rewardsDuration;
        emit RewardTokenAdded(address(rewardToken), rewardsDuration);
    }

    /// @inheritdoc IStakingRewardsManager
    function initializeStakingToken(
        IERC20 _stakingToken
    ) external onlyGovernor {
        if (address(stakingToken) != address(0))
            revert StakingTokenAlreadyInitialized();
        stakingToken = _stakingToken;
        emit StakingTokenInitialized(address(_stakingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _stake(address account, uint256 amount) internal {
        if (amount == 0) revert CannotStakeZero();
        if (address(stakingToken) == address(0))
            revert StakingTokenNotInitialized();
        _totalSupply += amount;
        _balances[account] += amount;

        stakingToken.safeTransferFrom(account, address(this), amount);
        emit Staked(account, amount);
    }

    function _withdraw(uint256 amount) internal {
        if (amount == 0) revert CannotWithdrawZero();
        _totalSupply -= amount;
        _balances[msg.sender] -= amount;
        stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) {
        for (uint256 i = 0; i < rewardsTokens.length; i++) {
            IERC20 rewardToken = rewardsTokens[i];
            RewardData storage data = rewardData[rewardToken];
            data.rewardPerTokenStored = rewardPerToken(rewardToken);
            data.lastUpdateTime = lastTimeRewardApplicable(rewardToken);
            if (account != address(0)) {
                rewards[rewardToken][account] = earned(account, rewardToken);
                userRewardPerTokenPaid[rewardToken][account] = data
                    .rewardPerTokenStored;
            }
        }
        _;
    }
}
