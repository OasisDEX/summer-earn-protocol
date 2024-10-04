// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/finance/VestingWallet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SummerVestingWallet
 * @dev Extension of OpenZeppelin's VestingWallet with custom vesting schedules and separate admin role.
 * Supports two types of vesting: Team vesting and Investor/Ex-Team vesting, both with a 6-month cliff.
 *
 * Vesting Schedules:
 * 1. Team Vesting:
 *    - Time-based: 8 quarterly releases over 2 years, starting after the 6-month cliff.
 *    - Performance-based: arbitrary amount of additional milestone-based releases, triggered by the guardian.
 * 2. Investor/Ex-Team Vesting:
 *    - Time-based only: 8 quarterly releases over 2 years, starting after the 6-month cliff.
 *
 * The guardian role can mark performance goals as reached for team vesting and recall unvested
 * performance-based tokens if necessary.
 */
contract SummerVestingWallet is VestingWallet, AccessControl {
    /// @dev Duration of a quarter in seconds
    uint256 private constant QUARTER = 90 days;
    /// @dev Duration of the cliff period in seconds
    uint256 private constant CLIFF = 180 days;

    /// @dev Role identifier for the admin role
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @dev Enum representing the types of vesting schedules
    enum VestingType {
        TeamVesting,
        InvestorExTeamVesting
    }

    /// @dev The type of vesting schedule for this wallet
    VestingType private immutable _vestingType;
    address public immutable token;

    // Performance-based vesting amounts
    uint256[] public goalAmounts;

    // Performance milestone flags
    bool[] public goalsReached;

    // Time-based vesting amount
    uint256 public timeBasedVestingAmount;

    error InvalidGoalNumber();
    error OnlyTeamVesting();
    error InvalidGoalArrayLength();

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

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param totalAllocation Total number of tokens allocated for vesting
     * @param timestamp The timestamp to check for vested tokens
     * @return uint256 The amount of tokens already vested
     * @custom:override Overrides the _vestingSchedule function from VestingWallet
     * @custom:internal-logic
     * - Checks if the timestamp is before the start of vesting, after the end, or during the vesting period
     * - Combines time-based and performance-based vesting calculations
     * @custom:effects
     * - Does not modify any state, view function only
     * @custom:security-considerations
     * - Ensure that the totalAllocation parameter accurately reflects the total vesting amount
     * - The function assumes that start() and duration() are correctly set
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
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            uint256 timeBasedVested = _calculateTimeBasedVesting(timestamp);
            uint256 performanceBasedVested = _calculatePerformanceBasedVesting();
            return timeBasedVested + performanceBasedVested;
        }
    }

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
     * @notice Adds a new performance-based vesting goal to the contract
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @dev The new goal is appended to the existing goalAmounts array
     * @dev A corresponding false value is added to the goalsReached array
     * @dev This function allows for dynamic expansion of performance-based vesting goals
     * @dev The caller must transfer the goalAmount of tokens to this contract after calling this function
     * @param goalAmount The amount of tokens associated with the new performance goal
     * @custom:requirements
     * - The caller must have the GUARDIAN_ROLE
     * - The contract must be able to receive the goalAmount of tokens
     * @custom:effects
     * - Increases the length of goalAmounts and goalsReached arrays by 1
     * - Sets the last element of goalAmounts to the provided goalAmount
     * - Sets the last element of goalsReached to false
     * @custom:security-considerations
     * - Ensure that the total of all goal amounts does not exceed the contract's token balance
     * - Consider any gas limitations when adding multiple goals, as array operations can be costly
     */
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

    /**
     * @notice Marks a specific performance goal as reached
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @param goalNumber The number of the goal to mark as reached (1-indexed)
     * @custom:requirements
     * - The caller must have the GUARDIAN_ROLE
     * - The goalNumber must be valid (between 1 and the total number of goals)
     * @custom:effects
     * - Sets the corresponding element in the goalsReached array to true
     * @custom:emits No events are emitted
     * @custom:security-considerations
     * - Ensure that only trusted guardians have the GUARDIAN_ROLE to prevent unauthorized vesting
     */
    function markGoalReached(
        uint256 goalNumber
    ) external onlyRole(GUARDIAN_ROLE) {
        if (goalNumber < 1 || goalNumber > goalAmounts.length) {
            revert InvalidGoalNumber();
        }
        goalsReached[goalNumber - 1] = true;
    }

    /**
     * @notice Recalls unvested performance-based tokens
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @dev It's only applicable for TeamVesting type
     * @custom:requirements
     * - The caller must have the GUARDIAN_ROLE
     * - The vesting type must be TeamVesting
     * @custom:effects
     * - Transfers unvested performance-based tokens to the caller
     * @custom:emits No events are emitted, but a token transfer occurs
     * @custom:security-considerations
     * - Ensure that only trusted guardians have the GUARDIAN_ROLE to prevent unauthorized token withdrawal
     * - This function allows the guardian to reclaim unvested tokens, which could potentially be used to reduce a beneficiary's expected vesting
     */
    function recallUnvestedTokens() external onlyRole(GUARDIAN_ROLE) {
        if (_vestingType != VestingType.TeamVesting) {
            revert OnlyTeamVesting();
        }
        uint256 unvestedPerformanceTokens = _calculateUnvestedPerformanceTokens();
        IERC20(token).transfer(msg.sender, unvestedPerformanceTokens);
    }
    /**
     * @notice Calculates the amount of unvested performance-based tokens
     * @dev This function is used internally to determine the amount of tokens that can be recalled
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
     * @notice Calculates the performance-based vesting amount
     * @dev This function is used internally to determine the amount of tokens vested based on reached performance goals
     * @dev It only applies to TeamVesting type; for other types, it returns 0
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

    /**
     * @notice Returns the vesting type of this wallet
     * @dev This function allows external contracts or users to check the vesting type
     * @return The VestingType enum value representing the vesting type (TeamVesting or InvestorExTeamVesting)
     * @custom:security-considerations
     * - This function doesn't modify state and doesn't have any significant security implications
     */
    function getVestingType() public view returns (VestingType) {
        return _vestingType;
    }
}
