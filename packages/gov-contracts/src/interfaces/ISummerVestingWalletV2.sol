// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title ISummerVestingWalletV2
 * @dev Interface for SummerVestingWalletV2, an improved vesting wallet with configurable parameters
 *
 * Key Features:
 * - Configurable cliff end date (Unix timestamp)
 * - Configurable cliff amount
 * - Configurable time-based vesting after cliff (number of periods and total amount)
 * - Custom performance criteria with amounts and descriptions
 * - Recallable tokens (both time-based and performance-based)
 * - Support for delegation of unvested amounts
 */
interface ISummerVestingWalletV2 {
    //////////////////////////////////////////////
    ///                STRUCTS                 ///
    //////////////////////////////////////////////

    /**
     * @dev Struct representing a performance goal
     * @param amount The amount of tokens for this goal
     * @param description A description of the performance criteria
     * @param reached Whether the goal has been reached
     */
    struct PerformanceGoal {
        uint256 amount;
        string description;
        bool reached;
    }

    /**
     * @dev Struct for vesting parameters
     * @param cliffEndTimestamp Unix timestamp when cliff period ends
     * @param cliffAmount Amount of tokens to vest at cliff
     * @param vestingPeriods Number of vesting periods after cliff
     * @param totalVestingAmount Total amount to vest over periods (excluding cliff)
     */
    struct VestingParams {
        uint64 cliffEndTimestamp;
        uint256 cliffAmount;
        uint256 vestingPeriods;
        uint256 totalVestingAmount;
    }

    //////////////////////////////////////////////
    ///             VIEW FUNCTIONS             ///
    //////////////////////////////////////////////

    /// @dev The token being vested
    function token() external view returns (address);

    /// @dev Get vesting parameters
    function vestingParams() external view returns (VestingParams memory);

    /// @dev Get performance goal by index
    function performanceGoals(
        uint256 index
    ) external view returns (PerformanceGoal memory);

    /// @dev Get number of performance goals
    function getPerformanceGoalsCount() external view returns (uint256);

    /// @dev Get amount per vesting period
    function getAmountPerPeriod() external view returns (uint256);

    //////////////////////////////////////////////
    ///           MUTATIVE FUNCTIONS           ///
    //////////////////////////////////////////////

    /**
     * @notice Adds a new performance-based vesting goal
     * @param goalAmount The amount of tokens for this goal
     * @param description Description of the performance criteria
     */
    function addNewGoal(uint256 goalAmount, string memory description) external;

    /**
     * @notice Marks a specific performance goal as reached
     * @param goalNumber The number of the goal to mark as reached (1-indexed)
     */
    function markGoalReached(uint256 goalNumber) external;

    /**
     * @notice Recalls unvested tokens (both time-based and performance-based)
     */
    function recallUnvestedTokens() external;

    //////////////////////////////////////////////
    ///                 ERRORS                 ///
    //////////////////////////////////////////////

    /// @dev Thrown when an invalid goal number is provided
    error InvalidGoalNumber();

    /// @dev Thrown when the token address is invalid
    error InvalidToken(address token);

    /// @dev Thrown when vesting parameters are invalid
    error InvalidVestingParams();

    /// @dev Thrown when cliff has not ended yet
    error CliffNotEnded();

    /// @dev Thrown when caller is not the factory owner
    error CallerIsNotFactoryOwner(address caller);

    /// @dev Thrown when trying to recall tokens that have already been recalled
    error TokensAlreadyRecalled();

    //////////////////////////////////////////////
    ///                 EVENTS                 ///
    //////////////////////////////////////////////

    /// @dev Emitted when a new goal is added
    event NewGoalAdded(
        uint256 indexed goalNumber,
        uint256 goalAmount,
        string description
    );

    /// @dev Emitted when a goal is reached
    event GoalReached(uint256 indexed goalNumber);

    /// @dev Emitted when unvested tokens are recalled
    event UnvestedTokensRecalled(uint256 tokensRecalled);
}
