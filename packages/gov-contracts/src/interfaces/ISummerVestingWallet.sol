// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ISummerVestingWallet
 * @dev Interface for SummerVestingWallet, an extension of OpenZeppelin's VestingWallet with custom vesting schedules
 * and separate admin role.
 * Supports two types of vesting: Team vesting and Investor/Ex-Team vesting, both with a 6-month cliff.
 *
 * Vesting Schedules:
 * 1. Team Vesting:
 *    - Time-based: Monthly releases over 2 years, starting after the 6-month cliff.
 *    - Performance-based: arbitrary amount of additional milestone-based releases, triggered by the guardian.
 * 2. Investor/Ex-Team Vesting:
 *    - Time-based only: Monthly releases over 2 years, starting after the 6-month cliff.
 *
 * The guardian role can mark performance goals as reached for team vesting and recall unvested
 * performance-based tokens if necessary.
 */
interface ISummerVestingWallet {
    /// @dev Enum representing the types of vesting schedules
    enum VestingType {
        TeamVesting,
        InvestorExTeamVesting
    }

    //////////////////////////////////////////////
    ///             VIEW FUNCTIONS             ///
    //////////////////////////////////////////////

    /// @dev The token being vested
    function token() external view returns (address);

    /// @dev Performance-based vesting amounts
    function goalAmounts(uint256 index) external view returns (uint256);

    /// @dev Performance milestone flags
    function goalsReached(uint256 index) external view returns (bool);

    /// @dev Time-based vesting amount
    function timeBasedVestingAmount() external view returns (uint256);

    /**
     * @dev Returns the vesting type of this wallet
     * @return The VestingType enum value representing the vesting type (TeamVesting or InvestorExTeamVesting)
     */
    function getVestingType() external view returns (VestingType);

    //////////////////////////////////////////////
    ///           MUTATIVE FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @notice Adds a new performance-based vesting goal to the contract
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @dev The new goal is appended to the existing goalAmounts array
     * @dev A corresponding false value is added to the goalsReached array
     * @dev This function allows for dynamic expansion of performance-based vesting goals
     * @dev The caller must transfer the goalAmount of tokens to this contract after calling this function
     * @param goalAmount The amount of tokens associated with the new performance goal
     */
    function addNewGoal(uint256 goalAmount) external;

    /**
     * @notice Marks a specific performance goal as reached
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @param goalNumber The number of the goal to mark as reached (1-indexed)
     */
    function markGoalReached(uint256 goalNumber) external;

    /**
     * @notice Recalls unvested performance-based tokens
     * @dev This function can only be called by an address with the GUARDIAN_ROLE
     * @dev It's only applicable for TeamVesting type
     */
    function recallUnvestedTokens() external;

    //////////////////////////////////////////////
    ///                 ERRORS                 ///
    //////////////////////////////////////////////

    /// @dev Thrown when an invalid goal number is provided
    error InvalidGoalNumber();

    /// @dev Thrown when a function is called that's only applicable to TeamVesting
    error OnlyTeamVesting();

    /// @dev Thrown when the goal array length is invalid
    error InvalidGoalArrayLength();

    /// @dev Thrown when the token address is invalid
    error InvalidToken(address token);

    /// @dev Emitted when a new goal is added
    event NewGoalAdded(uint256 goalAmount, uint256 goalNumber);

    /// @dev Emitted when a goal is reached
    event GoalReached(uint256 goalNumber);

    /// @dev Emitted when unvested tokens are recalled
    event UnvestedTokensRecalled(uint256 unvestedTokens);
}
