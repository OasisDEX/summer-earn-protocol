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
        uint256 amount
    ) external override updateReward(_msgSender()) {
        _stake(amount);
        _updateSmoothedDecayFactor(_msgSender());
    }

    /// @inheritdoc IStakingRewardsManager
    function withdraw(
        uint256 amount
    ) public override updateReward(_msgSender()) {
        _withdraw(amount);
        _updateSmoothedDecayFactor(_msgSender());
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
        uint256 latestSmoothedDecayFactor = _calculateSmoothedDecayFactor(
            account
        );

        return (rawEarned * latestSmoothedDecayFactor) / 1e18;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) override {
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
        userSmoothedDecayFactor[account] = _calculateSmoothedDecayFactor(
            account
        );
    }

    /**
     * @notice Calculates the smoothed decay factor for a given account without modifying state
     * @param account The address of the account to calculate for
     * @return The calculated smoothed decay factor
     */
    function _calculateSmoothedDecayFactor(
        address account
    ) internal view returns (uint256) {
        uint256 currentDecayFactor = governor.getDecayFactor(account);

        // If there's no existing smoothed factor, return the current factor
        if (userSmoothedDecayFactor[account] == 0) {
            return currentDecayFactor;
        }

        // Apply exponential moving average (EMA) smoothing
        return
            ((currentDecayFactor * DECAY_SMOOTHING_FACTOR) +
                (userSmoothedDecayFactor[account] *
                    (1000000 - DECAY_SMOOTHING_FACTOR))) / 1000000;
    }
}
