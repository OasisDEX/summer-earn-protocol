// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ReentrancyGuardTransient} from "@summerfi/dependencies/openzeppelin-next/ReentrancyGuardTransient.sol";
import {StakingRewardsManagerBase} from "@summerfi/rewards-contracts/contracts/StakingRewardsManagerBase.sol";
import {IStakingRewardsManagerBase} from "@summerfi/rewards-contracts/interfaces/IStakingRewardsManagerBase.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IGovernanceRewardsManager} from "../interfaces/IGovernanceRewardsManager.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Constants} from "@summerfi/constants/Constants.sol";
import {ISummerToken} from "../interfaces/ISummerToken.sol";
import {DecayController} from "./DecayController.sol";

/**
 * @title GovernanceRewardsManager
 * @notice Contract for managing governance rewards with multiple reward tokens in the Summer protocol
 * @dev Implements IGovernanceRewardsManager interface and inherits from StakingRewardsManagerBase
 */
contract GovernanceRewardsManager is
    IGovernanceRewardsManager,
    StakingRewardsManagerBase,
    DecayController
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Smoothing factor base for decay calculations (1e18)
     */
    uint256 public constant DECAY_SMOOTHING_FACTOR_BASE = Constants.WAD;

    /**
     * @notice Smoothing factor for decay calculations (0.2 * 1e18)
     */
    uint256 public constant DECAY_SMOOTHING_FACTOR =
        DECAY_SMOOTHING_FACTOR_BASE / 5; // represents 0.2

    /**
     * @notice Mapping of user addresses to their smoothed decay factors
     */
    mapping(address account => uint256 smoothedDecayFactor)
        public userSmoothedDecayFactor;

    /**
     * @notice Updates rewards for an account before executing a function
     * @param account The address of the account to update rewards for
     * @dev Updates reward data for all reward tokens
     */
    modifier updateReward(address account) override {
        _updateReward(account);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the contract with the protocol access manager
     * @param _stakingToken Address of the staking token
     * @param _accessManager Address of the ProtocolAccessManager contract
     */
    constructor(
        address _stakingToken,
        address _accessManager
    ) StakingRewardsManagerBase(_accessManager) DecayController(_stakingToken) {
        stakingToken = IERC20(_stakingToken);
        _setRewardsManager(address(this));
    }

    /**
     * @notice Internal function to initialize the staking token
     * @param _stakingToken The ERC20 token used for staking
     */
    function _initialize(IERC20 _stakingToken) internal override {
        stakingToken = _stakingToken;
        emit StakingTokenInitialized(address(_stakingToken));
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
    function stakeOnBehalfOf(
        address receiver,
        uint256 amount
    ) external override updateDecay(receiver) {
        _stake(_msgSender(), receiver, amount);
    }

    /**
     * @notice No op function to satisfy IGovernanceRewardsManager interface
     */
    function unstakeOnBehalfOf(address, address, uint256) external override {
        /* no op */
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function stake(
        uint256 amount
    )
        external
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        updateDecay(_msgSender())
    {
        _stake(_msgSender(), _msgSender(), amount);
    }

    /// @inheritdoc IStakingRewardsManagerBase
    function unstake(
        uint256 amount
    )
        external
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        updateReward(_msgSender())
        updateDecay(_msgSender())
    {
        _unstake(_msgSender(), _msgSender(), amount);
    }

    /**
     * @notice External function to update smoothed decay factor
     * @param account The address to update
     * @dev Only callable by the SummerToken or this contract
     */
    function updateSmoothedDecayFactor(
        address account
    ) external onlyDecayController {
        _updateSmoothedDecayFactor(account);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IGovernanceRewardsManager
    function balanceOf(
        address account
    )
        public
        view
        override(IGovernanceRewardsManager, StakingRewardsManagerBase)
        returns (uint256)
    {
        return super.balanceOf(account);
    }

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
                                INTERNAL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the smoothed decay factor for a given account
     * @param account The address of the account to update
     */
    function _updateSmoothedDecayFactor(address account) internal {
        if (account != address(0)) {
            userSmoothedDecayFactor[account] = _calculateSmoothedDecayFactor(
                account
            );
        }
    }

    /**
     * @notice Calculates the smoothed decay factor for a given account without modifying state
     * @param account The address of the account to calculate for
     * @return The calculated smoothed decay factor
     */
    function _calculateSmoothedDecayFactor(
        address account
    ) internal view returns (uint256) {
        uint256 currentDecayFactor = ISummerToken(address(stakingToken))
            .getDecayFactor(account);

        // If there's no existing smoothed factor, return the current factor
        if (userSmoothedDecayFactor[account] == 0) {
            return currentDecayFactor;
        }

        // Apply exponential moving average (EMA) smoothing
        // Formula: EMA = α * currentValue + (1 - α) * previousEMA
        // Where α is the smoothing factor (DECAY_SMOOTHING_FACTOR / DECAY_SMOOTHING_FACTOR_BASE)
        return
            ((currentDecayFactor * DECAY_SMOOTHING_FACTOR) +
                (userSmoothedDecayFactor[account] *
                    (DECAY_SMOOTHING_FACTOR_BASE - DECAY_SMOOTHING_FACTOR))) /
            DECAY_SMOOTHING_FACTOR_BASE;
    }
}
