// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIntentHandler} from "../../interfaces/IIntentHandler.sol";
import {IIntentBondFactory} from "../../interfaces/IIntentBondFactory.sol";
import {IIntentOracle} from "../../interfaces/IIntentOracle.sol";
import {ISolverBond} from "./IntentBondFactory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IntentHandler
 * @notice Contract that manages the lifecycle of intent-based bonds using individual solver bond contracts
 * @dev Handles intent creation, solving, activation, settlement, and resignation
 */
contract IntentHandler is IIntentHandler, ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ARK_ROLE = keccak256("ARK_ROLE");
    bytes32 public constant SOLVER_ROLE = keccak256("SOLVER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    uint256 public constant MAX_PRICE_AGE = 1 hours;
    uint256 public constant MIN_TERM = 1 days;
    uint256 public constant MAX_TERM = 365 days;

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    mapping(address => Intent) public intents;
    IIntentBondFactory public immutable intentBondFactory;
    IIntentOracle public immutable intentOracle;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _intentBondFactory, address _intentOracle) {
        intentBondFactory = IIntentBondFactory(_intentBondFactory);
        intentOracle = IIntentOracle(_intentOracle);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyArk() {
        if (!hasRole(ARK_ROLE, msg.sender)) revert UnauthorizedCaller();
        _;
    }

    modifier onlySolver() {
        if (!hasRole(SOLVER_ROLE, msg.sender)) revert UnauthorizedCaller();
        _;
    }

    modifier onlyLiquidator() {
        if (!hasRole(LIQUIDATOR_ROLE, msg.sender)) revert UnauthorizedCaller();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createIntent(
        address ark,
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address summerToken,
        address oracle,
        uint256 expiry
    ) external override onlyArk {
        // Check if intent already exists by checking if any field is non-zero
        if (intents[ark].requiredNotional != 0) revert IntentAlreadyExists();
        if (term < MIN_TERM || term > MAX_TERM) revert InvalidState();
        if (expiry <= block.timestamp) revert IntentExpired();

        intents[ark] = Intent({
            requiredNotional: requiredNotional,
            term: term,
            targetYield: targetYield,
            summerToken: summerToken,
            oracle: oracle,
            expiry: expiry,
            solver: address(0),
            escrowedYield: 0,
            startTime: 0,
            state: IntentState.Created
        });

        emit IntentCreated(
            ark,
            requiredNotional,
            term,
            targetYield,
            summerToken,
            oracle,
            expiry
        );
    }

    function solveIntent(
        address ark,
        address solverAddress,
        uint256 escrowedYield
    ) external override onlySolver {
        Intent storage intent = intents[ark];
        if (intent.state != IntentState.Created) revert IntentNotFound();
        if (block.timestamp > intent.expiry) revert IntentExpired();

        // Check if solver is vouched with sufficient bond
        if (
            !intentBondFactory.isSolverVouched(
                solverAddress,
                intent.requiredNotional
            )
        ) revert InsufficientBond();

        // Verify oracle is not stale
        if (intentOracle.isPriceStale(intent.summerToken, MAX_PRICE_AGE))
            revert InvalidOracle();

        intent.solver = solverAddress;
        intent.escrowedYield = escrowedYield;
        intent.state = IntentState.Solved;

        emit IntentSolved(ark, solverAddress, escrowedYield);
    }

    function activateIntent(address ark) external override onlySolver {
        Intent storage intent = intents[ark];
        if (intent.state != IntentState.Solved) revert IntentNotSolved();
        if (intent.solver != msg.sender) revert UnauthorizedCaller();

        intent.startTime = block.timestamp;
        intent.state = IntentState.Active;

        emit IntentActivated(ark, intent.solver, block.timestamp);
    }

    function settleIntent(address ark) external override onlySolver {
        Intent storage intent = intents[ark];
        if (intent.state != IntentState.Active) revert InvalidState();
        if (intent.solver != msg.sender) revert UnauthorizedCaller();
        if (block.timestamp < intent.startTime + intent.term)
            revert InvalidState();

        intent.state = IntentState.Settled;

        // No need to release bond - solver keeps their bond in their individual contract
        emit IntentSettled(ark, intent.solver, intent.escrowedYield);
    }

    function resignByArk(address ark) external override onlyArk {
        Intent storage intent = intents[ark];
        if (intent.state != IntentState.Created) revert InvalidState();

        intent.state = IntentState.ResignedByArk;

        emit IntentResignedByArk(ark, address(0), 0);
    }

    function resignBySolver(address ark) external override onlySolver {
        Intent storage intent = intents[ark];
        if (
            intent.state != IntentState.Solved &&
            intent.state != IntentState.Active
        ) revert InvalidState();
        if (intent.solver != msg.sender) revert UnauthorizedCaller();

        intent.state = IntentState.ResignedBySolver;

        // Get the solver's bond amount and slash bond (50% penalty)
        uint256 solverBondAmount = intentBondFactory.getSolverBondAmount(
            msg.sender
        );
        uint256 slashAmount = solverBondAmount / 2;

        // Get the solver's bond contract and slash the bond
        address solverBond = intentBondFactory.getSolverBond(msg.sender);
        ISolverBond(solverBond).slashBond(slashAmount);

        emit IntentResignedBySolver(
            ark,
            msg.sender,
            slashAmount,
            intent.escrowedYield
        );
    }

    function getIntent(
        address ark
    ) external view override returns (Intent memory) {
        return intents[ark];
    }

    function intentExists(address ark) external view override returns (bool) {
        return intents[ark].requiredNotional != 0;
    }

    /*//////////////////////////////////////////////////////////////
                                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function grantArkRole(address ark) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ARK_ROLE, ark);
    }

    function grantSolverRole(
        address solver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(SOLVER_ROLE, solver);
    }

    function grantLiquidatorRole(
        address liquidator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LIQUIDATOR_ROLE, liquidator);
    }
}
