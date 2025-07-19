// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWalletV2} from "../interfaces/ISummerVestingWalletV2.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SummerVestingWalletV2
 * @dev Improved vesting wallet with configurable parameters and enhanced functionality
 *
 * Features:
 * - Configurable cliff end timestamp
 * - Configurable cliff amount
 * - Configurable vesting periods and amounts after cliff
 * - Performance-based vesting with custom descriptions
 * - Recall functionality for both time-based and performance-based tokens
 * - Monthly vesting periods (30 days each)
 */
contract SummerVestingWalletV2 is ISummerVestingWalletV2, VestingWallet {
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////
    ///                CONSTANTS               ///
    //////////////////////////////////////////////

    /// @dev Duration of a month in seconds (30 days)
    uint256 private constant MONTH = 30 days;

    //////////////////////////////////////////////
    ///             STATE VARIABLES            ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWalletV2
    address public immutable token;

    /// @dev Address of the factory that created this vesting wallet
    address public immutable factory;

    /// @dev Vesting parameters
    VestingParams private _vestingParams;

    /// @dev Array of performance goals
    PerformanceGoal[] private _performanceGoals;

    /// @dev Flag to indicate if tokens have been recalled (wallet is bricked)
    bool public isRecalled;

    //////////////////////////////////////////////
    ///                MODIFIERS               ///
    //////////////////////////////////////////////

    /**
     * @dev Modifier to restrict access to the factory owner (multisig)
     */
    modifier onlyFactoryOwner() {
        if (msg.sender != Ownable(factory).owner()) {
            revert CallerIsNotFactoryOwner(msg.sender);
        }
        _;
    }

    //////////////////////////////////////////////
    ///              CONSTRUCTOR               ///
    //////////////////////////////////////////////

    /**
     * @dev Constructor that sets up the vesting wallet
     * @param _token The address of the token to be vested
     * @param beneficiaryAddress Address of the beneficiary
     * @param vestingParams_ The vesting parameters
     * @param performanceGoals_ Initial performance goals
     * @param _factory The address of the factory that created this wallet
     */
    constructor(
        address _token,
        address beneficiaryAddress,
        VestingParams memory vestingParams_,
        PerformanceGoal[] memory performanceGoals_,
        address _factory
    )
        VestingWallet(
            beneficiaryAddress,
            vestingParams_.cliffEndTimestamp,
            uint64(vestingParams_.vestingPeriods * MONTH)
        )
    {
        if (_token == address(0)) {
            revert InvalidToken(_token);
        }

        if (
            vestingParams_.cliffEndTimestamp <= block.timestamp ||
            (vestingParams_.totalVestingAmount > 0 &&
                vestingParams_.vestingPeriods == 0)
        ) {
            revert InvalidVestingParams();
        }

        token = _token;
        factory = _factory;
        _vestingParams = vestingParams_;

        // Add initial performance goals
        for (uint256 i = 0; i < performanceGoals_.length; i++) {
            _performanceGoals.push(performanceGoals_[i]);
        }
    }

    //////////////////////////////////////////////
    ///             VIEW FUNCTIONS             ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWalletV2
    function vestingParams() external view returns (VestingParams memory) {
        return _vestingParams;
    }

    /// @inheritdoc ISummerVestingWalletV2
    function performanceGoals(
        uint256 goalNumber
    ) external view returns (PerformanceGoal memory) {
        if (goalNumber < 1 || goalNumber > _performanceGoals.length) {
            revert InvalidGoalNumber();
        }
        return _performanceGoals[goalNumber - 1];
    }

    /// @inheritdoc ISummerVestingWalletV2
    function getPerformanceGoalsCount() external view returns (uint256) {
        return _performanceGoals.length;
    }

    /// @inheritdoc ISummerVestingWalletV2
    function getAmountPerPeriod() external view returns (uint256) {
        if (_vestingParams.vestingPeriods == 0) {
            return 0;
        }
        return
            _vestingParams.totalVestingAmount / _vestingParams.vestingPeriods;
    }

    //////////////////////////////////////////////
    ///           EXTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWalletV2
    function addNewGoal(
        uint256 goalAmount,
        string memory description
    ) external onlyFactoryOwner {
        _performanceGoals.push(
            PerformanceGoal({
                amount: goalAmount,
                description: description,
                reached: false
            })
        );

        // Transfer tokens for the new goal
        IERC20(token).safeTransferFrom(msg.sender, address(this), goalAmount);

        emit NewGoalAdded(_performanceGoals.length, goalAmount, description);
    }

    /// @inheritdoc ISummerVestingWalletV2
    function markGoalReached(uint256 goalNumber) external onlyFactoryOwner {
        if (goalNumber < 1 || goalNumber > _performanceGoals.length) {
            revert InvalidGoalNumber();
        }
        _performanceGoals[goalNumber - 1].reached = true;
        emit GoalReached(goalNumber);
    }

    /// @inheritdoc ISummerVestingWalletV2
    function recallUnvestedTokens() external onlyFactoryOwner {
        if (isRecalled) {
            revert TokensAlreadyRecalled();
        }

        // Get ALL tokens from this wallet - no calculations needed
        uint256 totalBalance = IERC20(token).balanceOf(address(this));

        // Brick the wallet permanently
        isRecalled = true;

        // Transfer ALL tokens to admin (vested + unvested = everything)
        if (totalBalance > 0) {
            IERC20(token).safeTransfer(msg.sender, totalBalance);
        }

        emit UnvestedTokensRecalled(totalBalance);
    }

    //////////////////////////////////////////////
    ///           INTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param timestamp The timestamp to check for vested tokens
     * @return uint256 The amount of tokens already vested
     */
    function _vestingSchedule(
        uint256,
        uint64 timestamp
    ) internal view override returns (uint256) {
        // If tokens have been recalled, no more vesting
        if (isRecalled || timestamp < _vestingParams.cliffEndTimestamp) {
            return 0;
        }

        uint256 cliffVested = _calculateCliffVesting(timestamp);
        uint256 timeBasedVested = _calculateTimeBasedVesting(timestamp);
        uint256 performanceBasedVested = _calculatePerformanceBasedVesting();

        return cliffVested + timeBasedVested + performanceBasedVested;
    }

    //////////////////////////////////////////////
    ///           PRIVATE FUNCTIONS            ///
    //////////////////////////////////////////////

    /**
     * @dev Calculates cliff vesting amount
     * @param timestamp Current timestamp
     * @return Amount vested from cliff
     */
    function _calculateCliffVesting(
        uint64 timestamp
    ) private view returns (uint256) {
        if (timestamp >= _vestingParams.cliffEndTimestamp) {
            return _vestingParams.cliffAmount;
        }
        return 0;
    }

    /**
     * @dev Calculates time-based vesting amount after cliff
     * @param timestamp Current timestamp
     * @return Amount vested from time-based schedule
     */
    function _calculateTimeBasedVesting(
        uint64 timestamp
    ) private view returns (uint256) {
        if (
            _vestingParams.totalVestingAmount == 0 ||
            _vestingParams.vestingPeriods == 0
        ) {
            return 0;
        }

        uint256 timeSinceCliff = timestamp - _vestingParams.cliffEndTimestamp;
        uint256 elapsedMonths = timeSinceCliff / MONTH;

        if (elapsedMonths >= _vestingParams.vestingPeriods) {
            // All periods have passed, return full amount
            return _vestingParams.totalVestingAmount;
        }

        // Calculate vested amount based on periods passed
        uint256 amountPerPeriod = _vestingParams.totalVestingAmount /
            _vestingParams.vestingPeriods;
        return elapsedMonths * amountPerPeriod;
    }

    /**
     * @dev Calculates performance-based vesting amount
     * @return Amount vested from performance goals
     */
    function _calculatePerformanceBasedVesting()
        private
        view
        returns (uint256)
    {
        uint256 vested = 0;
        for (uint256 i = 0; i < _performanceGoals.length; i++) {
            if (_performanceGoals[i].reached) {
                vested += _performanceGoals[i].amount;
            }
        }
        return vested;
    }
}
