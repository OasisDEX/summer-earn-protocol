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
 *    - Performance-based: 4 additional milestone-based releases, triggered by the guardian.
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
    uint256 public goal1Amount;
    uint256 public goal2Amount;
    uint256 public goal3Amount;
    uint256 public goal4Amount;

    // Performance milestone flags
    bool public goal1Reached;
    bool public goal2Reached;
    bool public goal3Reached;
    bool public goal4Reached;

    // Time-based vesting amount
    uint256 public timeBasedVestingAmount;

    error InvalidGoalNumber();
    error OnlyTeamVesting();

    /**
     * @dev Constructor that sets up the vesting wallet with a specific vesting type
     * @param beneficiaryAddress Address of the beneficiary to whom vested tokens are transferred
     * @param startTimestamp Unix timestamp marking the start of the vesting period
     * @param durationSeconds Duration of the vesting period in seconds
     * @param vestingType Type of vesting schedule (0 for TeamVesting, 1 for InvestorExTeamVesting)
     * @param guardianAddress Address to be granted the guardian role
     */
    constructor(
        address _token,
        address beneficiaryAddress,
        uint64 startTimestamp,
        uint64 durationSeconds,
        VestingType vestingType,
        uint256 _timeBasedVestingAmount,
        uint256 _goal1Amount,
        uint256 _goal2Amount,
        uint256 _goal3Amount,
        uint256 _goal4Amount,
        address guardianAddress
    ) VestingWallet(beneficiaryAddress, startTimestamp, durationSeconds) {
        _vestingType = vestingType;
        timeBasedVestingAmount = _timeBasedVestingAmount;
        goal1Amount = _goal1Amount;
        goal2Amount = _goal2Amount;
        goal3Amount = _goal3Amount;
        goal4Amount = _goal4Amount;
        token = _token;

        _grantRole(GUARDIAN_ROLE, guardianAddress);
    }

    /**
     * @dev Calculates the amount of tokens that has vested at a specific time
     * @param totalAllocation Total number of tokens allocated for vesting
     * @param timestamp The timestamp to check for vested tokens
     * @return The amount of tokens already vested
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
     * @return The amount of tokens already vested
     */
    function _calculateTimeBasedVesting(
        uint64 timestamp
    ) private view returns (uint256) {
        if (timestamp < start() + CLIFF) {
            return 0;
        }
        uint256 quartersDuringCliff = (CLIFF ) / QUARTER;
        uint256 elapsedQuarters = (timestamp - start() - CLIFF) /
            QUARTER +
            quartersDuringCliff;
        return (timeBasedVestingAmount * elapsedQuarters) / 8;
    }

    function _calculatePerformanceBasedVesting()
        private
        view
        returns (uint256)
    {
        if (_vestingType != VestingType.TeamVesting) {
            return 0;
        }
        uint256 vested = 0;
        if (goal1Reached) vested += goal1Amount;
        if (goal2Reached) vested += goal2Amount;
        if (goal3Reached) vested += goal3Amount;
        if (goal4Reached) vested += goal4Amount;
        return vested;
    }

    function markGoalReached(
        uint8 goalNumber
    ) external onlyRole(GUARDIAN_ROLE) {
        if (goalNumber < 1 || goalNumber > 4) {
            revert InvalidGoalNumber();
        }
        if (goalNumber == 1) goal1Reached = true;
        else if (goalNumber == 2) goal2Reached = true;
        else if (goalNumber == 3) goal3Reached = true;
        else if (goalNumber == 4) goal4Reached = true;
    }

    function recallUnvestedTokens() external onlyRole(GUARDIAN_ROLE) {
        if (_vestingType != VestingType.TeamVesting) {
            revert OnlyTeamVesting();
        }
        uint256 unvestedPerformanceTokens = _calculateUnvestedPerformanceTokens();
        IERC20(token).transfer(msg.sender, unvestedPerformanceTokens);
    }

    function _calculateUnvestedPerformanceTokens()
        private
        view
        returns (uint256)
    {
        uint256 totalPerformanceTokens = goal1Amount +
            goal2Amount +
            goal3Amount +
            goal4Amount;
        uint256 vestedPerformanceTokens = _calculatePerformanceBasedVesting();
        return totalPerformanceTokens - vestedPerformanceTokens;
    }

    function getVestingType() public view returns (VestingType) {
        return _vestingType;
    }
}
