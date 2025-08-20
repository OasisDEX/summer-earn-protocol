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

    event IntentCreated(bytes32 orderId, Intent intent);

    event IntentSolved(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    event IntentActivated(
        address indexed ark,
        address indexed solver,
        uint256 startTime
    );

    event IntentSettled(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    event IntentResignedByArk(
        address indexed ark,
        address indexed solver,
        uint256 escrowedYield
    );

    event IntentResignedBySolver(
        address indexed ark,
        address indexed solver,
        uint256 slashedAmount,
        uint256 escrowedYield
    );

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error IntentHandler__IntentAlreadyExists();
    error IntentHandler__IntentNotFound();
    error IntentHandler__IntentExpired();
    error IntentHandler__IntentNotSolved();
    error IntentHandler__InsufficientBond();
    error IntentHandler__InvalidOracle();
    error IntentHandler__InvalidState();
    error IntentHandler__UnauthorizedCaller();
    error IntentHandler__ConstructorParamsInvalid(string reason);
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
