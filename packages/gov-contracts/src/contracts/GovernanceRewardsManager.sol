// SPDX-License-Identifier: BUSL-1.1
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
import {WrappedStakingToken} from "./WrappedStakingToken.sol";

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
     * @notice Wrapped version of staking token for rewards
     */
    address public immutable wrappedStakingToken;

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
     * @param accessManager Address of the ProtocolAccessManager contract
     */
    constructor(
        address _stakingToken,
        address accessManager
    ) StakingRewardsManagerBase(accessManager) DecayController(_stakingToken) {
        stakingToken = _stakingToken;
        wrappedStakingToken = address(new WrappedStakingToken(stakingToken));
        _setRewardsManager(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStakingRewardsManagerBase
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

    /// @inheritdoc IStakingRewardsManagerBase
    function stake(
        uint256 amount
    )
        external
        override(IStakingRewardsManagerBase, StakingRewardsManagerBase)
        updateDecay(_msgSender())
        updateReward(_msgSender())
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
        address rewardToken
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

    /// @inheritdoc IGovernanceRewardsManager
    function calculateSmoothedDecayFactor(
        address account
    ) external view returns (uint256) {
        return _calculateSmoothedDecayFactor(account);
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

    /**
     * @notice Override _stake to wrap tokens
     * @param from The address to transfer tokens from
     * @param receiver The address to receive tokens
     * @param amount The amount of tokens to transfer
     */
    function _stake(
        address from,
        address receiver,
        uint256 amount
    ) internal override {
        if (receiver == address(0)) revert CannotStakeToZeroAddress();
        if (amount == 0) revert CannotStakeZero();
        if (address(stakingToken) == address(0)) {
            revert StakingTokenNotInitialized();
        }

        address delegate = ISummerToken(address(stakingToken)).delegates(
            receiver
        );
        if (delegate == address(0)) {
            revert NotDelegated();
        }

        totalSupply += amount;
        _balances[receiver] += amount;

        IERC20(stakingToken).safeTransferFrom(from, address(this), amount);
        IERC20(stakingToken).forceApprove(wrappedStakingToken, amount);
        WrappedStakingToken(wrappedStakingToken).depositFor(
            address(this),
            amount
        );

        emit Staked(from, receiver, amount);
    }

    /**
     * @notice Override _unstake to unwrap tokens
     * @param from The address to transfer tokens from
     * @param receiver The address to receive tokens
     * @param amount The amount of tokens to transfer
     */
    function _unstake(
        address from,
        address receiver,
        uint256 amount
    ) internal virtual override {
        if (amount == 0) revert CannotUnstakeZero();

        address delegate = ISummerToken(address(stakingToken)).delegates(
            receiver
        );
        if (delegate == address(0)) {
            revert NotDelegated();
        }

        totalSupply -= amount;
        _balances[from] -= amount;

        // Send direct to receiver to avoid any interim state where voting units might be incorrectly calculated
        WrappedStakingToken(wrappedStakingToken).withdrawTo(receiver, amount);

        emit Unstaked(from, receiver, amount);
    }
}
