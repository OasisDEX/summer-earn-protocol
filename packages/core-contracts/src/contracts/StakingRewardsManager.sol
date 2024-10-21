// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title StakingRewardsManager
 * @notice Contract for managing staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewards interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 * @dev Inspired by Synthetix's StakingRewards contract: https://github.com/Synthetixio/synthetix/blob/v2.101.3/contracts/StakingRewards.sol
 */
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

    IERC20[] public rewardTokens;
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
     * @param params Struct containing initialization parameters
     */
    constructor(
        StakingRewardsParams memory params
    ) ProtocolAccessManaged(params.accessManager) {
        if (params.rewardTokens.length == 0) revert NoRewardTokens();
        for (uint256 i = 0; i < params.rewardTokens.length; i++) {
            rewardTokens.push(IERC20(params.rewardTokens[i]));
            rewardData[IERC20(params.rewardTokens[i])].rewardsDuration = 7 days;
        }
    }

    /*//////////////////////////////////////////////////////////////
                                VIEWS
    //////////////////////////////////////////////////////////////*/

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
    function stake(uint256 amount) external virtual updateReward(_msgSender()) {
        _stake(amount);
    }

    /// @notice Allows the FleetCommander to stake on behalf of a user
    /// @param receiver The account to stake for
    /// @param amount The amount of tokens to stake
    function stakeOnBehalf(
        address receiver,
        uint256 amount
    ) external virtual updateReward(receiver) {
        _stakeFrom(_msgSender(), receiver, amount);
    }

    /// @inheritdoc IStakingRewardsManager
    function withdraw(uint256 amount) public virtual updateReward(msg.sender) {
        _withdraw(amount);
    }

    /// @inheritdoc IStakingRewardsManager
    function getReward() public virtual nonReentrant updateReward(msg.sender) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
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
        getReward();
        _withdraw(_balances[msg.sender]);
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
        rewardTokens.push(rewardToken);
        rewardData[rewardToken].rewardsDuration = rewardsDuration;
        emit RewardTokenAdded(address(rewardToken), rewardsDuration);
    }

    /// @inheritdoc IStakingRewardsManager
    function initialize(IERC20 _stakingToken) external onlyGovernor {
        if (address(stakingToken) != address(0))
            revert StakingTokenAlreadyInitialized();
        stakingToken = _stakingToken;
        emit StakingTokenInitialized(address(_stakingToken));
    }

    /// @notice Removes a reward token from the list of reward tokens
    /// @param rewardToken The address of the reward token to remove
    function removeRewardToken(IERC20 rewardToken) external onlyGovernor {
        if (rewardData[rewardToken].rewardsDuration == 0)
            revert RewardTokenDoesNotExist();
        if (block.timestamp <= rewardData[rewardToken].periodFinish)
            revert RewardPeriodNotComplete();

        // Find and remove the token from the rewardTokens array
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == rewardToken) {
                rewardTokens[i] = rewardTokens[rewardTokens.length - 1];
                rewardTokens.pop();
                break;
            }
        }

        // Reset the reward data for this token
        delete rewardData[rewardToken];

        emit RewardTokenRemoved(address(rewardToken));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _stake(uint256 amount) internal {
        if (amount == 0) revert CannotStakeZero();
        if (address(stakingToken) == address(0))
            revert StakingTokenNotInitialized();
        totalSupply += amount;
        _balances[_msgSender()] += amount;

        stakingToken.safeTransferFrom(_msgSender(), address(this), amount);
        emit Staked(_msgSender(), amount);
    }

    function _stakeFrom(
        address from,
        address account,
        uint256 amount
    ) internal {
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
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 rewardToken = rewardTokens[i];
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
