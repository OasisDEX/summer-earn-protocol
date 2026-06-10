// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IIntentHandler
 * @notice Interface for the intent handler contract that manages the lifecycle of intent-based bonds
 */
interface IIntentHandler {
    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new intent is created
    /// @param orderId Unique identifier of the intent order
    /// @param intent Struct containing all parameters of the created intent
    event IntentCreated(bytes32 orderId, Intent intent);

    /// @notice Emitted when an intent is successfully solved by a solver
    /// @param ark The address of the Ark that created the intent
    /// @param solver The address of the solver that solved the intent
    /// @param escrowedYield The amount of yield escrowed by the solver
    event IntentSolved(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    /// @notice Emitted when a solved intent is activated
    /// @param ark The address of the Ark
    /// @param solver The address of the solver
    /// @param startTime The block timestamp when the intent was activated
    event IntentActivated(
        address indexed ark,
        address indexed solver,
        uint256 startTime
    );

    /// @notice Emitted when an intent is settled
    /// @param ark The address of the Ark
    /// @param solver The address of the solver
    /// @param escrowedYield The escrowed yield amount returned to solver/ark
    event IntentSettled(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    /// @notice Emitted when an intent is resigned by the Ark (user)
    /// @param ark The address of the Ark
    /// @param solver The address of the solver
    /// @param escrowedYield The amount of escrowed yield refunded
    event IntentResignedByArk(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    /// @notice Emitted when an intent is resigned by the solver, causing a bond penalty
    /// @param ark The address of the Ark
    /// @param solver The address of the solver
    /// @param slashedAmount The amount of solver's bond slashed
    /// @param escrowedYield The amount of escrowed yield refunded/processed
    event IntentResignedBySolver(
        address indexed ark,
        address indexed solver,
        uint256 slashedAmount,
        uint256 escrowedYield
    );

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when attempting to create an intent that already exists
    error IntentHandler__IntentAlreadyExists();

    /// @notice Thrown when the specified intent does not exist
    error IntentHandler__IntentNotFound();

    /// @notice Thrown when attempting to interact with an expired intent
    error IntentHandler__IntentExpired();

    /// @notice Thrown when attempting to settle/activate an intent that has not been solved
    error IntentHandler__IntentNotSolved();

    /// @notice Thrown when the solver has an insufficient bond balance to solve the intent
    error IntentHandler__InsufficientBond();

    /// @notice Thrown when the price oracle address is invalid
    error IntentHandler__InvalidOracle();

    /// @notice Thrown when the intent is in an invalid state for the requested operation
    error IntentHandler__InvalidState();

    /// @notice Thrown when the caller is not authorized to perform the operation
    error IntentHandler__UnauthorizedCaller();

    /// @notice Thrown when constructor parameters are invalid
    /// @param reason String detailing the validation failure
    error IntentHandler__ConstructorParamsInvalid(string reason);

    /// @notice Thrown when the yield amount escrowed is less than the required amount
    error IntentHandler__TooLittleEscrowed();

    /*//////////////////////////////////////////////////////////////
                                        STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Intent {
        address user;
        uint256 requiredNotional;
        uint256 requiredBond;
        uint256 term;
        uint256 targetYield;
        address token;
        address oracle;
        uint256 expiry;
    }

    /// @notice Enum representing the lifecycle states of an intent
    enum IntentState {
        None,
        Created,
        Solved,
        Active,
        Settled,
        UserResigned,
        SolverResigned
    }

    /*//////////////////////////////////////////////////////////////
                                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new intent
     * @param intent Intent struct containing intent information
     */
    function createIntent(Intent memory intent) external;

    /**
     * @notice Solver solves an intent directly
     * @param intent Intent struct containing intent information
     * @param escrowedYield Amount of yield escrowed upfront
     */
    function solveIntent(Intent memory intent, uint256 escrowedYield) external;

    /**
     * @notice Settles an intent (can only be called by the solver)
     * @param intent Intent struct containing intent information
     */
    function settleIntent(Intent memory intent) external;

    /**
     * @notice Resigns an intent by the Ark (can only be called before solving)
     * @param intent Intent struct containing intent information
     */
    function resignByUser(Intent memory intent) external;

    /**
     * @notice Resigns an intent by the solver (50% bond penalty)
     * @param intent Intent struct containing intent information
     */
    function resignBySolver(Intent memory intent) external;
}
