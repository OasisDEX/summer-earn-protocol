// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ReentrancyGuardTransient} from "@openzeppelin-next/ReentrancyGuardTransient.sol";
import {StakingRewardsManager} from "./StakingRewardsManager.sol";
import {IDecayableStakingRewardsManager} from "../interfaces/IDecayableStakingRewardsManager.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SummerGovernor} from "@summerfi/earn-gov-contracts/contracts/SummerGovernor.sol";

/**
 * @title DecayableStakingRewardsManager
 * @notice Contract for managing decayable staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IDecayableStakingRewardsManager interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 */
contract DecayableStakingRewardsManager is
    IDecayableStakingRewardsManager,
    StakingRewardsManager
{
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    SummerGovernor public immutable governor;

    // Decay factor smoothing constant (0-1000000)
    uint256 public constant DECAY_SMOOTHING_FACTOR = 200000; // represents 0.2
    mapping(address => uint256) public userSmoothedDecayFactor;

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
                            VIEWS
    //////////////////////////////////////////////////////////////*/
    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IDecayableStakingRewardsManager
    function earned(
        address account,
        IERC20 rewardToken
    ) public view override returns (uint256) {
        uint256 rawEarned = super.earned(account, rewardToken);
        return (rawEarned * userSmoothedDecayFactor[account]) / 1e18;
    }

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
            updateSmoothedDecayFactor(account);
        }
        _;
    }

    /**
     * @notice Updates the smoothed decay factor for a given account
     * @param account The address of the account to update
     */
    function updateSmoothedDecayFactor(address account) internal {
        uint256 currentDecayFactor = governor.getVotingPower(account, 1e18);

        if (userSmoothedDecayFactor[account] == 0) {
            userSmoothedDecayFactor[account] = currentDecayFactor;
        } else {
            userSmoothedDecayFactor[account] =
                ((currentDecayFactor * DECAY_SMOOTHING_FACTOR) +
                    (userSmoothedDecayFactor[account] *
                        (1000000 - DECAY_SMOOTHING_FACTOR))) /
                1000000;
        }
    }

    /// @inheritdoc IDecayableStakingRewardsManager
    function stake(
        address account,
        uint256 amount
    ) external override updateReward(account) {
        super.stake(account, amount);
        updateSmoothedDecayFactor(account);
    }

    /// @inheritdoc IDecayableStakingRewardsManager
    function withdraw(uint256 amount) public override updateReward(msg.sender) {
        super.withdraw(amount);
        updateSmoothedDecayFactor(msg.sender);
    }
}
