// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWalletV2} from "../interfaces/ISummerVestingWalletV2.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

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
contract SummerVestingWalletV2 is
    ISummerVestingWalletV2,
    VestingWallet,
    ProtocolAccessManaged
{
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

    /// @dev Vesting parameters
    VestingParams private _vestingParams;

    /// @dev Array of performance goals
    PerformanceGoal[] private _performanceGoals;

    /// @dev Amount of time-based tokens already recalled
    uint256 public timeBasedTokensRecalled;

    /// @dev Amount of performance-based tokens already recalled
    uint256 public performanceBasedTokensRecalled;

    //////////////////////////////////////////////
    ///              CONSTRUCTOR               ///
    //////////////////////////////////////////////

    /**
     * @dev Constructor that sets up the vesting wallet
     * @param _token The address of the token to be vested
     * @param beneficiaryAddress Address of the beneficiary
     * @param vestingParams_ The vesting parameters
     * @param performanceGoals_ Initial performance goals
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(
        address _token,
        address beneficiaryAddress,
        VestingParams memory vestingParams_,
        PerformanceGoal[] memory performanceGoals_,
        address _accessManager
    )
        VestingWallet(
            beneficiaryAddress,
            vestingParams_.cliffEndTimestamp,
            uint64(vestingParams_.vestingPeriods * MONTH)
        )
        ProtocolAccessManaged(_accessManager)
    {
        if (_token == address(0)) {
            revert InvalidToken(_token);
        }

        if (
            vestingParams_.cliffEndTimestamp <= block.timestamp ||
            vestingParams_.vestingPeriods == 0 ||
            (vestingParams_.totalVestingAmount > 0 && vestingParams_.vestingPeriods == 0)
        ) {
            revert InvalidVestingParams();
        }

        token = _token;
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
    function performanceGoals(uint256 index) external view returns (PerformanceGoal memory) {
        if (index >= _performanceGoals.length) {
            revert InvalidGoalIndex();
        }
        return _performanceGoals[index];
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
        return _vestingParams.totalVestingAmount / _vestingParams.vestingPeriods;
    }

    //////////////////////////////////////////////
    ///           EXTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWalletV2
    function addNewGoal(uint256 goalAmount, string memory description) external onlyFoundation {
        _performanceGoals.push(PerformanceGoal({
            amount: goalAmount,
            description: description,
            reached: false
        }));

        // Transfer tokens for the new goal
        IERC20(token).safeTransferFrom(msg.sender, address(this), goalAmount);

        emit NewGoalAdded(_performanceGoals.length - 1, goalAmount, description);
    }

    /// @inheritdoc ISummerVestingWalletV2
    function markGoalReached(uint256 goalIndex) external onlyFoundation {
        if (goalIndex >= _performanceGoals.length) {
            revert InvalidGoalIndex();
        }

        _performanceGoals[goalIndex].reached = true;
        emit GoalReached(goalIndex);
    }

    /// @inheritdoc ISummerVestingWalletV2
    function recallUnvestedTokens() external onlyFoundation returns (uint256 timeBasedRecalled, uint256 performanceBasedRecalled) {
        // Calculate unvested time-based tokens
        timeBasedRecalled = _calculateUnvestedTimeBasedTokens();
        
        // Calculate unvested performance-based tokens
        performanceBasedRecalled = _calculateUnvestedPerformanceTokens();

        // Mark recalled tokens
        timeBasedTokensRecalled += timeBasedRecalled;
        performanceBasedTokensRecalled += performanceBasedRecalled;

        // Reset unreached performance goals to 0
        for (uint256 i = 0; i < _performanceGoals.length; i++) {
            if (!_performanceGoals[i].reached) {
                _performanceGoals[i].amount = 0;
            }
        }

        // Transfer recalled tokens back to admin
        uint256 totalRecalled = timeBasedRecalled + performanceBasedRecalled;
        if (totalRecalled > 0) {
            IERC20(token).safeTransfer(msg.sender, totalRecalled);
        }

        emit UnvestedTokensRecalled(timeBasedRecalled, performanceBasedRecalled);
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
    function _calculateCliffVesting(uint64 timestamp) private view returns (uint256) {
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
    function _calculateTimeBasedVesting(uint64 timestamp) private view returns (uint256) {
        if (timestamp < _vestingParams.cliffEndTimestamp) {
            return 0;
        }

        if (_vestingParams.totalVestingAmount == 0 || _vestingParams.vestingPeriods == 0) {
            return 0;
        }

        uint256 timeSinceCliff = timestamp - _vestingParams.cliffEndTimestamp;
        uint256 periodsPassed = timeSinceCliff / MONTH;

        if (periodsPassed >= _vestingParams.vestingPeriods) {
            // All periods have passed, return full amount minus recalled
            return _vestingParams.totalVestingAmount - timeBasedTokensRecalled;
        }

        // Calculate vested amount based on periods passed
        uint256 amountPerPeriod = _vestingParams.totalVestingAmount / _vestingParams.vestingPeriods;
        uint256 vestedAmount = periodsPassed * amountPerPeriod;
        
        return vestedAmount > timeBasedTokensRecalled ? vestedAmount - timeBasedTokensRecalled : 0;
    }

    /**
     * @dev Calculates performance-based vesting amount
     * @return Amount vested from performance goals
     */
    function _calculatePerformanceBasedVesting() private view returns (uint256) {
        uint256 vested = 0;
        for (uint256 i = 0; i < _performanceGoals.length; i++) {
            if (_performanceGoals[i].reached) {
                vested += _performanceGoals[i].amount;
            }
        }
        return vested;
    }

    /**
     * @dev Calculates unvested time-based tokens
     * @return Amount of unvested time-based tokens
     */
    function _calculateUnvestedTimeBasedTokens() private view returns (uint256) {
        // Calculate how much should be vested now (without considering recalled tokens)
        uint256 timeSinceCliff = block.timestamp >= _vestingParams.cliffEndTimestamp ? 
                                 block.timestamp - _vestingParams.cliffEndTimestamp : 0;
        uint256 periodsPassed = timeSinceCliff / MONTH;
        
        uint256 shouldBeVested;
        if (periodsPassed >= _vestingParams.vestingPeriods) {
            shouldBeVested = _vestingParams.totalVestingAmount;
        } else {
            uint256 amountPerPeriod = _vestingParams.totalVestingAmount / _vestingParams.vestingPeriods;
            shouldBeVested = periodsPassed * amountPerPeriod;
        }
        
        // Calculate how much is still unvested
        uint256 totalAllocated = _vestingParams.totalVestingAmount;
        uint256 totalVested = shouldBeVested + timeBasedTokensRecalled;
        
        return totalAllocated > totalVested ? totalAllocated - totalVested : 0;
    }

    /**
     * @dev Calculates unvested performance-based tokens
     * @return Amount of unvested performance-based tokens
     */
    function _calculateUnvestedPerformanceTokens() private view returns (uint256) {
        uint256 unvested = 0;
        for (uint256 i = 0; i < _performanceGoals.length; i++) {
            if (!_performanceGoals[i].reached && _performanceGoals[i].amount > 0) {
                unvested += _performanceGoals[i].amount;
            }
        }
        return unvested;
    }
} 