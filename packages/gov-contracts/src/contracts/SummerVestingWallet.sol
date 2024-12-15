// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ISummerVestingWallet} from "../interfaces/ISummerVestingWallet.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {VestingWallet} from "@openzeppelin/contracts/finance/VestingWallet.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SummerVestingWallet
 * @dev Implementation of ISummerVestingWallet
 */
contract SummerVestingWallet is
    ISummerVestingWallet,
    VestingWallet,
    AccessControl
{
    //////////////////////////////////////////////
    ///                CONSTANTS               ///
    //////////////////////////////////////////////

    /// @dev Duration of a quarter in seconds
    uint256 private constant QUARTER = 90 days;
    /// @dev Duration of the cliff period in seconds
    uint256 private constant CLIFF = 180 days;

    /// @inheritdoc ISummerVestingWallet
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

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
    uint256 public timeBasedVestingAmount;

    //////////////////////////////////////////////
    ///              CONSTRUCTOR               ///
    //////////////////////////////////////////////

    /**
     * @dev Constructor that sets up the vesting wallet with a specific vesting type
     * @param beneficiaryAddress Address of the beneficiary to whom vested tokens are transferred
     * @param startTimestamp Unix timestamp marking the start of the vesting period
     * @param durationSeconds Duration of the vesting period in seconds
     * @param vestingType Type of vesting schedule (0 for TeamVesting, 1 for InvestorExTeamVesting)
     * @param guardianAddress Address to be granted the guardian role
     * @param _goalAmounts Array of goal amounts for performance-based vesting
     */
    constructor(
        address _token,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        VestingType vestingType,
        uint256 _timeBasedVestingAmount,
        uint256[] memory _goalAmounts,
        address guardianAddress
    ) VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds) {
        _vestingType = vestingType;
        timeBasedVestingAmount = _timeBasedVestingAmount;
        goalAmounts = _goalAmounts;
        goalsReached = new bool[](_goalAmounts.length);
        token = _token;

        _grantRole(GUARDIAN_ROLE, guardianAddress);
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
    function addNewGoal(uint256 goalAmount) external onlyRole(GUARDIAN_ROLE) {
        goalAmounts.push(goalAmount);
        goalsReached.push(false);
        SafeERC20.safeTransferFrom(
            IERC20(token),
            msg.sender,
            address(this),
            goalAmount
        );
    }

    /// @inheritdoc ISummerVestingWallet
    function markGoalReached(
        uint256 goalNumber
    ) external onlyRole(GUARDIAN_ROLE) {
        if (goalNumber < 1 || goalNumber > goalAmounts.length) {
            revert InvalidGoalNumber();
        }
        goalsReached[goalNumber - 1] = true;
    }

    /// @inheritdoc ISummerVestingWallet
    function recallUnvestedTokens() external onlyRole(GUARDIAN_ROLE) {
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
    }

    //////////////////////////////////////////////
    ///           INTERNAL FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param totalAllocation Total number of tokens allocated for vesting
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
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view override returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else {
            uint256 timeBasedVested = _calculateTimeBasedVesting(timestamp);
            uint256 performanceBasedVested = _calculatePerformanceBasedVesting();
            return timeBasedVested + performanceBasedVested;
        }
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
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the CLIFF and QUARTER constants are correctly set
     * - The function assumes that start() is correctly set
     * @custom:gas-considerations
     * - This function performs several mathematical operations, which may impact gas usage
     * - Consider caching results if called frequently within the same transaction
     */
    function _calculateTimeBasedVesting(
        uint64 timestamp
    ) private view returns (uint256) {
        if (timestamp < start() + CLIFF) {
            return 0;
        }
        uint256 quartersDuringCliff = (CLIFF) / QUARTER;
        uint256 elapsedQuarters = (timestamp - start() - CLIFF) /
            QUARTER +
            quartersDuringCliff;
        return (timeBasedVestingAmount * elapsedQuarters) / 8;
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
        uint256 totalPerformanceTokens = 0;
        for (uint256 i = 0; i < goalAmounts.length; i++) {
            totalPerformanceTokens += goalAmounts[i];
        }
        uint256 vestedPerformanceTokens = _calculatePerformanceBasedVesting();
        return totalPerformanceTokens - vestedPerformanceTokens;
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
        for (uint256 i = 0; i < goalAmounts.length; i++) {
            if (goalsReached[i]) vested += goalAmounts[i];
        }
        return vested;
    }
}
