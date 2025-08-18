// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIntentHandler} from "../../interfaces/IIntentHandler.sol";
import {IIntentBondFactory} from "../../interfaces/IIntentBondFactory.sol";
import {IIntentOracle} from "../../interfaces/IIntentOracle.sol";
import {ISolverBond} from "./IntentBondFactory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IAdapter} from "../../interfaces/intents/IAdapter.sol";

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
    mapping(address solver => IAdapter solverAdapter) public solverAdapters;
    IIntentBondFactory public immutable intentBondFactory;
    IIntentOracle public immutable intentOracle;
    IERC20 public immutable summerToken;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _intentBondFactory,
        address _intentOracle,
        address _summerToken
    ) {
        if (_summerToken == address(0))
            revert IntentHandler__ConstructorParamsInvalid(
                "Summer token cannot be zero address"
            );
        if (_intentBondFactory == address(0))
            revert IntentHandler__ConstructorParamsInvalid(
                "Intent bond factory cannot be zero address"
            );
        if (_intentOracle == address(0))
            revert IntentHandler__ConstructorParamsInvalid(
                "Intent oracle cannot be zero address"
            );

        summerToken = IERC20(_summerToken);
        intentBondFactory = IIntentBondFactory(_intentBondFactory);
        intentOracle = IIntentOracle(_intentOracle);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyArk() {
        if (!hasRole(ARK_ROLE, msg.sender))
            revert IntentHandler__UnauthorizedCaller();
        _;
    }

    modifier onlySolver() {
        if (!hasRole(SOLVER_ROLE, msg.sender))
            revert IntentHandler__UnauthorizedCaller();
        _;
    }

    modifier onlyLiquidator() {
        if (!hasRole(LIQUIDATOR_ROLE, msg.sender))
            revert IntentHandler__UnauthorizedCaller();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createIntent(
        address user,
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address token,
        address oracle,
        uint256 expiry
    ) external override onlyArk {
        // Check if intent already exists by checking if any field is non-zero
        if (intents[user].requiredNotional != 0)
            revert IntentHandler__IntentAlreadyExists();
        if (term < MIN_TERM || term > MAX_TERM)
            revert IntentHandler__InvalidState();
        if (expiry <= block.timestamp) revert IntentHandler__IntentExpired();

        intents[user] = Intent({
            requiredNotional: requiredNotional,
            term: term,
            targetYield: targetYield,
            token: token,
            oracle: oracle,
            expiry: expiry,
            solver: address(0),
            escrowedYield: 0,
            startTime: 0,
            state: IntentState.Created
        });

        emit IntentCreated(
            user,
            requiredNotional,
            term,
            targetYield,
            token,
            oracle,
            expiry
        );
    }

    function solveIntent(
        address user,
        address solverAddress,
        uint256 escrowedYield
    ) external override onlySolver {
        Intent storage intent = intents[user];
        if (intent.state != IntentState.Created)
            revert IntentHandler__IntentNotFound();
        if (block.timestamp > intent.expiry)
            revert IntentHandler__IntentExpired();

        // Check if solver is vouched with sufficient bond
        if (
            !intentBondFactory.isSolverVouched(
                solverAddress,
                intent.requiredNotional
            )
        ) revert IntentHandler__InsufficientBond();

        // Verify oracle is not stale
        if (intentOracle.isPriceStale(address(summerToken), MAX_PRICE_AGE))
            revert IntentHandler__InvalidOracle();

        intent.solver = solverAddress;
        intent.escrowedYield = escrowedYield;
        intent.state = IntentState.Solved;

        IAdapter adapter = solverAdapters[solverAddress];
        IERC20(intent.token).transferFrom(
            user,
            address(this),
            intent.requiredNotional
        );
        IERC20(intent.token).forceApprove(
            address(adapter),
            intent.requiredNotional
        );
        adapter.deposit(intent.token, intent.requiredNotional, user);

        emit IntentSolved(user, solverAddress, escrowedYield);
    }

    function activateIntent(address user) external override onlySolver {
        Intent storage intent = intents[user];
        if (intent.state != IntentState.Solved)
            revert IntentHandler__IntentNotSolved();
        if (intent.solver != msg.sender)
            revert IntentHandler__UnauthorizedCaller();

        intent.startTime = block.timestamp;
        intent.state = IntentState.Active;

        emit IntentActivated(user, intent.solver, block.timestamp);
    }

    function settleIntent(address user) external override onlySolver {
        Intent storage intent = intents[user];
        if (intent.state != IntentState.Active)
            revert IntentHandler__InvalidState();
        if (intent.solver != msg.sender)
            revert IntentHandler__UnauthorizedCaller();
        if (block.timestamp < intent.startTime + intent.term)
            revert IntentHandler__InvalidState();

        intent.state = IntentState.Settled;

        // No need to release bond - solver keeps their bond in their individual contract
        emit IntentSettled(user, intent.solver, intent.escrowedYield);
    }

    function resignByArk(address user) external override onlyArk {
        Intent storage intent = intents[user];
        if (intent.state != IntentState.Created)
            revert IntentHandler__InvalidState();

        intent.state = IntentState.ResignedByArk;

        emit IntentResignedByArk(user, address(0), 0);
    }

    function resignBySolver(address user) external override onlySolver {
        Intent storage intent = intents[user];
        if (
            intent.state != IntentState.Solved &&
            intent.state != IntentState.Active
        ) revert IntentHandler__InvalidState();
        if (intent.solver != msg.sender)
            revert IntentHandler__UnauthorizedCaller();

        intent.state = IntentState.ResignedBySolver;

        // Get the solver's bond amount and slash bond (50% penalty)
        uint256 solverBondAmount = intentBondFactory.getSolverBondAmount(
            msg.sender
        );
        uint256 slashAmount = solverBondAmount / 2;

        // Slash the bond via the factory
        intentBondFactory.slashBond(msg.sender, slashAmount);

        emit IntentResignedBySolver(
            user,
            msg.sender,
            slashAmount,
            intent.escrowedYield
        );
    }

    function getIntent(
        address user
    ) external view override returns (Intent memory) {
        return intents[user];
    }

    function intentExists(address user) external view override returns (bool) {
        return intents[user].requiredNotional != 0;
    }

    /*//////////////////////////////////////////////////////////////
                                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function addSolverAdapter(
        address solver,
        address adapter
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // todo erc165 check if adapter is a valid adapter
        solverAdapters[solver] = IAdapter(adapter);
    }

    function removeSolverAdapter(
        address solver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        solverAdapters[solver] = IAdapter(address(0));
    }

    function grantArkRole(address user) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ARK_ROLE, user);
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
