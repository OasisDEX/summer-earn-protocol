// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title StakingRewardsManager
 * @notice Contract for managing staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewards interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 * @dev Inspired by Synthetix's StakingRewards contract:
 * https://github.com/Synthetixio/synthetix/blob/v2.101.3/contracts/StakingRewards.sol
 */
import {IStakingRewardsManagerBase} from "../interfaces/IStakingRewardsManagerBase.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {ReentrancyGuardTransient} from "@summerfi/dependencies/openzeppelin-next/ReentrancyGuardTransient.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Constants} from "@summerfi/constants/Constants.sol";

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
    using EnumerableSet for EnumerableSet.AddressSet;

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

    /* @notice List of all reward tokens supported by this contract */
    EnumerableSet.AddressSet internal _rewardTokensList;
    /* @notice The token that users stake to earn rewards */
    IERC20 public stakingToken;

    /* @notice Mapping of reward token to its reward distribution data */
    mapping(IERC20 rewardToken => RewardData) public rewardData;
    /* @notice Tracks the last reward per token paid to each user for each reward token */
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardPerTokenPaid))
        public userRewardPerTokenPaid;
    /* @notice Tracks the unclaimed rewards for each user for each reward token */
    mapping(IERC20 rewardToken => mapping(address account => uint256 rewardAmount))
        public rewards;

    /* @notice Total amount of tokens staked in the contract */
    uint256 public totalSupply;
    mapping(address account => uint256 balance) private _balances;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) virtual {
        _updateReward(account);
        _;
    }

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
        if (index >= _rewardTokensList.length()) revert IndexOutOfBounds();
        address rewardTokenAddress = _rewardTokensList.at(index);
        return IERC20(rewardTokenAddress);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function balanceOf(address account) public view virtual returns (uint256) {
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
                Constants.WAD) / totalSupply);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function earned(
        address account,
        IERC20 rewardToken
    ) public view virtual returns (uint256) {
        return _earned(account, rewardToken);
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

    /// @inheritdoc IStakingRewardsManagerBase
    function unstake(
        uint256 amount
    ) external virtual updateReward(_msgSender()) {
        _unstake(_msgSender(), _msgSender(), amount);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function getReward() public virtual nonReentrant {
        _getReward(_msgSender());
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function exit() external virtual {
        getReward();
        _unstake(_msgSender(), _msgSender(), _balances[_msgSender()]);
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
        if (address(rewardToken) == address(stakingToken))
            revert CantAddStakingTokenAsReward();
        RewardData storage rewardTokenData = rewardData[rewardToken];

        // If the reward token doesn't exist, add it
        if (!_rewardTokensList.contains(address(rewardToken))) {
            if (newRewardsDuration == 0) revert RewardsDurationCannotBeZero();
            _rewardTokensList.add(address(rewardToken));
            rewardTokenData.rewardsDuration = newRewardsDuration;
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

        uint256 totalReward;
        if (block.timestamp >= rewardTokenData.periodFinish) {
            totalReward = reward;
        } else {
            uint256 remaining = rewardTokenData.periodFinish - block.timestamp;
            uint256 leftover = remaining * rewardTokenData.rewardRate;
            totalReward = reward + leftover;
        }

        // Check balance first
        uint256 balance = rewardToken.balanceOf(address(this));
        if (totalReward > balance) revert ProvidedRewardTooHigh();

        // Calculate rate only once after validation
        rewardTokenData.rewardRate =
            totalReward /
            rewardTokenData.rewardsDuration;

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
        if (!_rewardTokensList.contains(address(rewardToken)))
            revert RewardTokenDoesNotExist();
        RewardData storage data = rewardData[rewardToken];
        if (block.timestamp <= data.periodFinish) {
            revert RewardPeriodNotComplete();
        }
        data.rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(address(rewardToken), _rewardsDuration);
    }

    /// @notice Removes a reward token from the list of reward tokens
    /// @param rewardToken The address of the reward token to remove
    function removeRewardToken(IERC20 rewardToken) external onlyGovernor {
        if (!_rewardTokensList.contains(address(rewardToken))) {
            revert RewardTokenDoesNotExist();
        }

        if (block.timestamp <= rewardData[rewardToken].periodFinish) {
            revert RewardPeriodNotComplete();
        }

        // Check if all tokens have been claimed, allowing a small dust balance
        uint256 remainingBalance = rewardToken.balanceOf(address(this));
        uint256 dustThreshold;

        try IERC20Metadata(address(rewardToken)).decimals() returns (
            uint8 decimals
        ) {
            // For tokens with 4 or fewer decimals, use a minimum threshold of 1
            // For tokens with more decimals, use 0.01% of 1 token
            if (decimals <= 4) {
                dustThreshold = 1;
            } else {
                dustThreshold = 100 * (10 ** (decimals - 4)); // 0.01% of 1 token
            }
        } catch {
            dustThreshold = 1e12; // Default threshold for tokens without decimals
        }

        if (remainingBalance > dustThreshold) {
            revert RewardTokenStillHasBalance(remainingBalance);
        }

        // Remove the token from the rewardTokens map
        _rewardTokensList.remove(address(rewardToken));

        // Reset the reward data for this token
        delete rewardData[rewardToken];

        emit RewardTokenRemoved(address(rewardToken));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the StakingRewardsManagerBase contract
    /// @param _stakingToken The address of the staking token
    function _initialize(IERC20 _stakingToken) internal virtual {}

    function _stake(address from, address receiver, uint256 amount) internal {
        if (amount == 0) revert CannotStakeZero();
        if (address(stakingToken) == address(0)) {
            revert StakingTokenNotInitialized();
        }
        totalSupply += amount;
        _balances[receiver] += amount;
        stakingToken.safeTransferFrom(from, address(this), amount);
        emit Staked(receiver, amount);
    }

    function _unstake(address from, address receiver, uint256 amount) internal {
        if (amount == 0) revert CannotUnstakeZero();
        totalSupply -= amount;
        _balances[from] -= amount;
        stakingToken.safeTransfer(receiver, amount);
        emit Unstaked(from, amount);
    }

    /*
     * @notice Internal function to calculate earned rewards for an account
     * @param account The address to calculate earnings for
     * @param rewardToken The reward token to calculate earnings for
     * @return The amount of reward tokens earned
     */
    function _earned(
        address account,
        IERC20 rewardToken
    ) internal view returns (uint256) {
        return
            (_balances[account] *
                (rewardPerToken(rewardToken) -
                    userRewardPerTokenPaid[rewardToken][account])) /
            Constants.WAD +
            rewards[rewardToken][account];
    }

    function _updateReward(address account) internal {
        uint256 rewardTokenCount = _rewardTokensList.length();
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardTokenAddress = _rewardTokensList.at(i);
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
    }

    /**
     * @notice Internal function to claim rewards for an account
     * @param account The address to claim rewards for
     * @dev rewards go straight to the user's wallet
     */
    function _getReward(address account) internal updateReward(account) {
        uint256 rewardTokenCount = _rewardTokensList.length();
        for (uint256 i = 0; i < rewardTokenCount; i++) {
            address rewardTokenAddress = _rewardTokensList.at(i);
            IERC20 rewardToken = IERC20(rewardTokenAddress);
            uint256 reward = rewards[rewardToken][account];
            if (reward > 0) {
                rewards[rewardToken][account] = 0;
                rewardToken.safeTransfer(account, reward);
                emit RewardPaid(account, address(rewardToken), reward);
            }
        }
    }
}
