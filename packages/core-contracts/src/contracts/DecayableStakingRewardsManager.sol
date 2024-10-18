// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ReentrancyGuardTransient} from "@openzeppelin-next/ReentrancyGuardTransient.sol";
import {StakingRewardsManager} from "./StakingRewardsManager.sol";
import {IStakingRewardsManager} from "../interfaces/IStakingRewardsManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SummerGovernor} from "@summerfi/earn-gov-contracts/contracts/SummerGovernor.sol";

/**
 * @title DecayableStakingRewardsManager
 * @notice Contract for managing decayable staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IStakingRewardsManager interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 */
contract DecayableStakingRewardsManager is StakingRewardsManager {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    SummerGovernor public immutable governor;

    // Decay factor smoothing constant (0-1000000)
    uint256 public constant DECAY_SMOOTHING_FACTOR = 200000; // represents 0.2
    mapping(address account => uint256 smoothedDecayFactor)
        public userSmoothedDecayFactor;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the DecayableStakingRewardsManager contract
     * @param params Struct containing initialization parameters
     * @param _governor Address of the SummerGovernor contract
     */
    constructor(
        StakingRewardsParams memory params,
        address _governor
    ) StakingRewardsManager(params) {
        governor = SummerGovernor(payable(_governor));
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManager
    function stake(
        address account,
        uint256 amount
    ) external override updateReward(account) {
        _stake(account, amount);
        _updateSmoothedDecayFactor(account);
    }

    /// @inheritdoc IStakingRewardsManager
    function withdraw(uint256 amount) public override updateReward(msg.sender) {
        _withdraw(amount);
        _updateSmoothedDecayFactor(msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManager
    function earned(
        address account,
        IERC20 rewardToken
    ) public view override returns (uint256) {
        uint256 rawEarned = _earned(account, rewardToken);
        return (rawEarned * userSmoothedDecayFactor[account]) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) override {
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
        if (account != address(0)) {
            _updateSmoothedDecayFactor(account);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the smoothed decay factor for a given account
     * @param account The address of the account to update
     */
    function _updateSmoothedDecayFactor(address account) internal {
        // Get the current decay factor (voting power) for the account
        uint256 currentDecayFactor = governor.getDecayFactor(account);

        // If this is the first update for the account, set the smoothed factor to the current factor
        if (userSmoothedDecayFactor[account] == 0) {
            userSmoothedDecayFactor[account] = currentDecayFactor;
        } else {
            // Apply exponential moving average (EMA) smoothing
            // Formula: newSmoothedFactor = (currentFactor * smoothingWeight) + (oldSmoothedFactor * (1 - smoothingWeight))
            // Where smoothingWeight = DECAY_SMOOTHING_FACTOR / 1000000 (0.2 or 20%)
            userSmoothedDecayFactor[account] =
                ((currentDecayFactor * DECAY_SMOOTHING_FACTOR) +
                    (userSmoothedDecayFactor[account] *
                        (1000000 - DECAY_SMOOTHING_FACTOR))) /
                1000000;
        }
    }
}
