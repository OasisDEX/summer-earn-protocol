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

    event IntentCreated(
        address indexed ark,
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address summerToken,
        address oracle,
        uint256 expiry
    );

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

    error IntentAlreadyExists();
    error IntentNotFound();
    error IntentExpired();
    error IntentNotSolved();
    error InsufficientBond();
    error InvalidOracle();
    error InvalidState();
    error UnauthorizedCaller();

    /*//////////////////////////////////////////////////////////////
                                        STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct Intent {
        uint256 requiredNotional;
        uint256 term;
        uint256 targetYield;
        address summerToken;
        address oracle;
        uint256 expiry;
        address solver;
        uint256 escrowedYield;
        uint256 startTime;
        IntentState state;
    }

    enum IntentState {
        Created,
        Solved,
        Active,
        Settled,
        ResignedByArk,
        ResignedBySolver
    }

    /*//////////////////////////////////////////////////////////////
                                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new intent
     * @param ark Address of the Ark contract
     * @param requiredNotional Required notional value for the intent
     * @param term Term length in seconds
     * @param targetYield Target yield amount
     * @param summerToken Address of Summer token for bonding
     * @param oracle Address of oracle for price verification
     * @param expiry Expiry timestamp
     */
    function createIntent(
        address ark,
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address summerToken,
        address oracle,
        uint256 expiry
    ) external;

    /**
     * @notice Solver solves an intent directly
     * @param ark Address of the Ark contract
     * @param solverAddress Address of the solver
     * @param escrowedYield Amount of yield escrowed upfront
     */
    function solveIntent(
        address ark,
        address solverAddress,
        uint256 escrowedYield
    ) external;

    /**
     * @notice Activates an intent (can only be called by the solver)
     * @param ark Address of the Ark contract
     */
    function activateIntent(address ark) external;

    /**
     * @notice Settles an intent (can only be called by the solver)
     * @param ark Address of the Ark contract
     */
    function settleIntent(address ark) external;

    /**
     * @notice Resigns an intent by the Ark (can only be called before solving)
     * @param ark Address of the Ark contract
     */
    function resignByArk(address ark) external;

    /**
     * @notice Resigns an intent by the solver (50% bond penalty)
     * @param ark Address of the Ark contract
     */
    function resignBySolver(address ark) external;

    /**
     * @notice Gets the intent information for an Ark
     * @param ark Address of the Ark contract
     * @return Intent struct containing intent information
     */
    function getIntent(address ark) external view returns (Intent memory);

    /**
     * @notice Checks if an intent exists
     * @param ark Address of the Ark contract
     * @return True if intent exists, false otherwise
     */
    function intentExists(address ark) external view returns (bool);
}
