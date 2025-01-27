// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISummerVestingWallet} from "../interfaces/ISummerVestingWallet.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";

/**
 * @title SummerVestingWallet
 * @dev Implementation of ISummerVestingWallet
 */
contract SummerVestingWallet is
    ISummerVestingWallet,
    VestingWallet,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;

    //////////////////////////////////////////////
    ///                CONSTANTS               ///
    //////////////////////////////////////////////

    /// @dev Duration of a month in seconds
    uint256 private constant MONTH = 30 days;
    /// @dev Duration of the cliff period in seconds
    uint256 private constant CLIFF = 180 days;

    /// @dev Duration of the vesting period in seconds
    uint64 private constant DURATION_SECONDS = 730 days; // 2 years for both vesting types

    //////////////////////////////////////////////
    ///             STATE VARIABLES            ///
    //////////////////////////////////////////////

    /// @dev The type of vesting schedule for this wallet
    VestingType private immutable _vestingType;

    /// @inheritdoc ISummerVestingWallet
    address public immutable token;

    // Performance-based vesting amounts
    uint256[] public goalAmounts;

    // Performance milestone flags
    bool[] public goalsReached;

    // Time-based vesting amount
    uint256 public immutable timeBasedVestingAmount;

    //////////////////////////////////////////////
    ///              CONSTRUCTOR               ///
    //////////////////////////////////////////////

    /**
     * @dev Constructor that sets up the vesting wallet with a specific vesting type
     * @param _token The address of the token to be vested
     * @param beneficiaryAddress Address of the beneficiary to whom vested tokens are transferred
     * @param startTimestamp Unix timestamp marking the start of the vesting period
     * @param vestingType Type of vesting schedule (0 for TeamVesting, 1 for InvestorExTeamVesting)
     * @param _timeBasedVestingAmount Amount of tokens to be vested time-based
     * @param _goalAmounts Array of goal amounts for performance-based vesting
     * @param _accessManager The address of the ProtocolAccessManager contract
     */
    constructor(
        address _token,
        address beneficiaryAddress,
        uint64 startTimestamp,
        VestingType vestingType,
        uint256 _timeBasedVestingAmount,
        uint256[] memory _goalAmounts,
        address _accessManager
    )
        VestingWallet(beneficiaryAddress, startTimestamp, DURATION_SECONDS)
        ProtocolAccessManaged(_accessManager)
    {
        _vestingType = vestingType;
        timeBasedVestingAmount = _timeBasedVestingAmount;
        if (_vestingType == VestingType.TeamVesting) {
            for (uint256 i = 0; i < _goalAmounts.length; i++) {
                _addNewGoal(_goalAmounts[i]);
            }
        } else if (_goalAmounts.length > 0) {
            revert OnlyTeamVesting();
        }
        token = _token;

        if (token == address(0)) {
            revert InvalidToken(_token);
        }
    }

    //////////////////////////////////////////////
    ///            PUBLIC FUNCTIONS            ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWallet
    function getVestingType() public view returns (VestingType) {
        return _vestingType;
    }

    //////////////////////////////////////////////
    ///           EXTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /// @inheritdoc ISummerVestingWallet
    function addNewGoal(uint256 goalAmount) external onlyFoundation {
        if (_vestingType != VestingType.TeamVesting) {
            revert OnlyTeamVesting();
        }
        _addNewGoal(goalAmount);
        SafeERC20.safeTransferFrom(
            IERC20(token),
            msg.sender,
            address(this),
            goalAmount
        );
    }

    function _addNewGoal(uint256 goalAmount) internal {
        goalAmounts.push(goalAmount);
        goalsReached.push(false);
        emit NewGoalAdded(goalAmount, goalAmounts.length);
    }

    /// @inheritdoc ISummerVestingWallet
    function markGoalReached(uint256 goalNumber) external onlyFoundation {
        if (goalNumber < 1 || goalNumber > goalAmounts.length) {
            revert InvalidGoalNumber();
        }
        goalsReached[goalNumber - 1] = true;
        emit GoalReached(goalNumber);
    }

    /// @inheritdoc ISummerVestingWallet
    function recallUnvestedTokens() external onlyFoundation {
        if (_vestingType != VestingType.TeamVesting) {
            revert OnlyTeamVesting();
        }
        uint256 unvestedPerformanceTokens = _calculateUnvestedPerformanceTokens();

        for (uint256 i = 0; i < goalAmounts.length; i++) {
            if (!goalsReached[i]) {
                goalAmounts[i] = 0;
            }
        }

        IERC20(token).transfer(msg.sender, unvestedPerformanceTokens);
        emit UnvestedTokensRecalled(unvestedPerformanceTokens);
    }

    //////////////////////////////////////////////
    ///           INTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param timestamp The timestamp to check for vested tokens
     * @return uint256 The amount of tokens already vested
     * @custom:override Overrides the _vestingSchedule function from VestingWallet
     * @custom:internal-logic
     * - Checks if the timestamp is before the start of vesting
     * - Combines time-based vesting (capped at timeBasedVestingAmount) and performance-based vesting (only for reached goals)
     * - Performance goals must be explicitly marked as reached to vest, regardless of time elapsed
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the totalAllocation parameter accurately reflects the total vesting amount
     * - The function assumes that start() is correctly set
     * - Performance-based tokens never vest unless their goals are explicitly reached
     * @custom:gas-considerations
     * - This function calls two other internal functions, which may impact gas usage
     * - Consider gas costs when frequently querying vested amounts
     */
    function _vestingSchedule(
        uint256,
        uint64 timestamp
    ) internal view override returns (uint256) {
        if (timestamp < start() + CLIFF) {
            return 0;
        }
        uint256 timeBasedVested = _calculateTimeBasedVesting(timestamp);
        uint256 performanceBasedVested = _calculatePerformanceBasedVesting();
        return timeBasedVested + performanceBasedVested;
    }

    //////////////////////////////////////////////
    ///           PRIVATE FUNCTIONS            ///
    //////////////////////////////////////////////

    /**
     * @dev Calculates the time-based vesting amount based on the vesting type and timestamp
     * @param timestamp The timestamp to check for vested tokens
     * @return uint256 The amount of tokens already vested based on time
     * @custom:internal-logic
     * - Checks if the timestamp is before the cliff period
     * - Calculates the number of quarters that have passed, including the cliff period
     * - Determines the vested amount based on elapsed quarters
     * - Caps the vested amount at the timeBasedVestingAmount
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the CLIFF and MONTH constants are correctly set
     * - The function assumes that start() is correctly set
     * @custom:gas-considerations
     * - This function performs several mathematical operations, which may impact gas usage
     * - Consider caching results if called frequently within the same transaction
     */
    function _calculateTimeBasedVesting(
        uint64 timestamp
    ) private view returns (uint256) {
        uint256 elapsedMonths = (timestamp - start()) / MONTH;
        uint256 _vestedAmount = (timeBasedVestingAmount * elapsedMonths) / 24;
        return
            _vestedAmount < timeBasedVestingAmount
                ? _vestedAmount
                : timeBasedVestingAmount;
    }

    /**
     * @dev Calculates the amount of unvested performance-based tokens
     * @return The total amount of unvested performance-based tokens
     * @custom:internal-logic
     * - Calculates the total amount of tokens allocated for all performance goals
     * - Subtracts the amount of tokens vested based on reached performance goals
     * @custom:performance-considerations
     * - The gas cost of this function increases linearly with the number of goals
     * - Consider gas limitations when adding a large number of goals
     */
    function _calculateUnvestedPerformanceTokens()
        private
        view
        returns (uint256)
    {
        uint256 unvestedAmount = 0;
        uint256 _goalLen = goalAmounts.length;
        for (uint256 i = 0; i < _goalLen; i++) {
            if (!goalsReached[i]) {
                unvestedAmount += goalAmounts[i];
            }
        }
        return unvestedAmount;
    }

    /**
     * @dev Calculates the performance-based vesting amount
     * @return The total amount of tokens vested based on reached performance goals
     * @custom:internal-logic
     * - Checks if the vesting type is TeamVesting
     * - Iterates through all goals, summing up the amounts for reached goals
     * @custom:performance-considerations
     * - The gas cost of this function increases linearly with the number of goals
     * - Consider gas limitations when adding a large number of goals
     */
    function _calculatePerformanceBasedVesting()
        private
        view
        returns (uint256)
    {
        if (_vestingType != VestingType.TeamVesting) {
            return 0;
        }
        uint256 vested = 0;
        uint256 _goalLen = goalAmounts.length;
        for (uint256 i = 0; i < _goalLen; i++) {
            if (goalsReached[i]) vested += goalAmounts[i];
        }
        return vested;
    }
}
