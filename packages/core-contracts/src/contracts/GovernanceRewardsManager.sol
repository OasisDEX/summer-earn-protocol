// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ReentrancyGuardTransient} from "@openzeppelin-next/ReentrancyGuardTransient.sol";
import {StakingRewardsManagerBase} from "./StakingRewardsManagerBase.sol";
import {IStakingRewardsManagerBase} from "../interfaces/IStakingRewardsManagerBase.sol";
import {ProtocolAccessManaged} from "./ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISummerGovernor} from "@summerfi/earn-gov-contracts/interfaces/ISummerGovernor.sol";
import {IGovernanceRewardsManager} from "../interfaces/IGovernanceRewardsManager.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Constants} from "./libraries/Constants.sol";

/**
 * @title GovernanceStakingRewardsManager
 * @notice Contract for managing governance staking rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IGovernanceStakingRewardsManager interface and inherits from ReentrancyGuardTransient and ProtocolAccessManaged
 * @dev Implements decayable staking rewards
 */
contract GovernanceRewardsManager is
    IGovernanceRewardsManager,
    StakingRewardsManagerBase
{
    using SafeERC20 for IERC20;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    ISummerGovernor public immutable governor;

    uint256 public constant DECAY_SMOOTHING_FACTOR_BASE = Constants.RAY;
    uint256 public constant DECAY_SMOOTHING_FACTOR =
        DECAY_SMOOTHING_FACTOR_BASE / 5; // represents 0.2
    mapping(address account => uint256 smoothedDecayFactor)
        public userSmoothedDecayFactor;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the DecayableStakingRewardsManager contract
     * @param _accessManager Address of the ProtocolAccessManager contract
     * @param _governor Address of the SummerGovernor contract
     * @param _summerToken Address of the SummerToken contract
     */
    constructor(
        address _accessManager,
        address _governor,
        address _summerToken
    ) StakingRewardsManagerBase(_accessManager) {
        governor = ISummerGovernor(payable(_governor));
        _initialize(IERC20(_summerToken));
    }

    function _initialize(IERC20 _stakingToken) internal override {
        stakingToken = _stakingToken;
        emit StakingTokenInitialized(address(_stakingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
    function stake(
        uint256 amount
    )
        external
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        updateReward(_msgSender())
    {
        _stake(_msgSender(), _msgSender(), amount);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function withdraw(
        uint256 amount
    )
        external
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        updateReward(_msgSender())
    {
        _withdraw(amount);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
    function earned(
        address account,
        IERC20 rewardToken
    )
        public
        view
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        returns (uint256)
    {
        uint256 rawEarned = _earned(account, rewardToken);
        uint256 latestSmoothedDecayFactor = _calculateSmoothedDecayFactor(
            account
        );

        return (rawEarned * latestSmoothedDecayFactor) / Constants.WAD;
    }

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier updateReward(address account) override {
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
                    (DECAY_SMOOTHING_FACTOR_BASE - DECAY_SMOOTHING_FACTOR))) /
            DECAY_SMOOTHING_FACTOR_BASE;
    }
}
