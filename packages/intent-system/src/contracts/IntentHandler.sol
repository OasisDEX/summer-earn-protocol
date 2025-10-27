// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IIntentHandler} from "../interfaces/IIntentHandler.sol";
import {IIntentBondFactory} from "../interfaces/IIntentBondFactory.sol";
import {IIntentOracle} from "../interfaces/IIntentOracle.sol";
import {ISolverBond} from "./IntentBondFactory.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IEscrow} from "../interfaces/IEscrow.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Escrow} from "./Escrow.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IArk} from "@summerfi/earn-protocol-contracts/interfaces/IArk.sol";
import {IArkConfigProvider} from "@summerfi/earn-protocol-contracts/interfaces/IArkConfigProvider.sol";
import {IFleetCommander} from "@summerfi/earn-protocol-contracts/interfaces/IFleetCommander.sol";

/**
 * @title IntentHandler
 * @notice Contract that manages the lifecycle of intent-based bonds using individual solver bond contracts
 * @dev Handles intent creation, solving, activation, settlement, and resignation
 * @dev Deploys escrows for each solver to hold yield
 */
contract IntentHandler is
    IIntentHandler,
    ReentrancyGuard,
    ProtocolAccessManaged
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_PRICE_AGE = 1 hours;
    uint256 public constant MIN_TERM = 1 days;
    uint256 public constant MAX_TERM = 365 days;
    uint256 public constant BUFFER_TIME = 10 minutes;

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 intentId => IntentState state) public intentStates;
    mapping(address solver => Escrow escrow) public solverEscrows;
    mapping(bytes32 intentId => address solver) public intentSolvers;
    mapping(bytes32 intentId => uint256 solveTime) public intentSolveTime;
    IIntentBondFactory public immutable intentBondFactory;
    IIntentOracle public immutable intentOracle;
    IERC20 public immutable summerToken;
    address public immutable accessManager;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _intentBondFactory,
        address _intentOracle,
        address _summerToken,
        address _accessManager
    ) ProtocolAccessManaged(_accessManager) {
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
        if (_accessManager == address(0))
            revert IntentHandler__ConstructorParamsInvalid(
                "Access manager cannot be zero address"
            );

        summerToken = IERC20(_summerToken);
        intentBondFactory = IIntentBondFactory(_intentBondFactory);
        intentBondFactory.setIntentHandler(address(this));
        intentOracle = IIntentOracle(_intentOracle);
        accessManager = _accessManager;
    }

    /*//////////////////////////////////////////////////////////////
                                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySolver() {
        if (address(solverEscrows[msg.sender]) == address(0))
            revert IntentHandler__UnauthorizedCaller();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createIntent(Intent memory intent) external onlyKeeper {
        bytes32 intentId = keccak256(abi.encode(intent));

        if (intentStates[intentId] != IntentState.None)
            revert IntentHandler__IntentAlreadyExists();
        if (intent.term < MIN_TERM || intent.term > MAX_TERM)
            revert IntentHandler__InvalidState();
        if (intent.expiry <= block.timestamp)
            revert IntentHandler__IntentExpired();

        intentStates[intentId] = IntentState.Created;
        emit IntentCreated(intentId, intent);
    }

    function solveIntent(
        Intent memory intent,
        uint256 escrowedYield
    ) external onlySolver {
        bytes32 intentId = keccak256(abi.encode(intent));
        if (intentStates[intentId] != IntentState.Created)
            revert IntentHandler__IntentNotFound();
        if (block.timestamp > intent.expiry)
            revert IntentHandler__IntentExpired();

        // Check if solver is vouched with sufficient bond
        if (!intentBondFactory.isSolverVouched(msg.sender, intent.requiredBond))
            revert IntentHandler__InsufficientBond();

        // Verify oracle is not stale
        // Note: Currently only checks staleness, but future versions may use price data
        // for dynamic bond requirements based on notional value
        if (intentOracle.isPriceStale(address(summerToken), MAX_PRICE_AGE))
            revert IntentHandler__InvalidOracle();
        if (intent.targetYield < escrowedYield) {
            revert IntentHandler__TooLittleEscrowed();
        }

        intentStates[intentId] = IntentState.Solved;
        intentSolveTime[intentId] = block.timestamp;
        intentSolvers[intentId] = msg.sender;

        Escrow escrow = solverEscrows[msg.sender];
        IERC20(intent.token).forceApprove(address(escrow), intent.targetYield);
        IERC20(intent.token).transferFrom(
            msg.sender,
            address(this),
            intent.targetYield
        );
        escrow.deposit(intent.token, escrowedYield, intentId);

        emit IntentSolved(intent.user, msg.sender, escrowedYield);
    }

    function settleIntent(Intent memory intent) external {
        bytes32 intentId = keccak256(abi.encode(intent));
        IntentState state = intentStates[intentId];

        if (state != IntentState.Solved) revert IntentHandler__InvalidState();
        if (block.timestamp < intent.expiry)
            revert IntentHandler__InvalidState();

        intentStates[intentId] = IntentState.Settled;

        address solver = intentSolvers[intentId];
        // Transfer escrowed yield to the user (ark)
        Escrow escrow = solverEscrows[solver];
        uint256 escrowedYield = escrow.withdraw(
            intent.token,
            intent.user,
            intentId
        );
        address bufferArk = address(
            IFleetCommander(IArkConfigProvider(intent.user).commander())
                .bufferArk()
        );
        IERC20(intent.token).transfer(bufferArk, escrowedYield);

        // No need to release bond - solver keeps their bond in their individual contract
        emit IntentSettled(intent.user, solver, escrowedYield);
    }

    function resignByUser(Intent memory intent) external onlyKeeper {
        bytes32 intentId = keccak256(abi.encode(intent));
        IntentState state = intentStates[intentId];
        if (state == IntentState.Solved) {
            // need to return the escrowed yield to the solver
            address solver = intentSolvers[intentId];
            Escrow escrow = solverEscrows[solver];
            escrow.withdraw(intent.token, solver, intentId);
        } else if (state != IntentState.Created)
            revert IntentHandler__InvalidState();

        intentStates[intentId] = IntentState.UserResigned;

        emit IntentResignedByArk(intent.user, address(0), 0);
    }

    function resignBySolver(Intent memory intent) external {
        bytes32 intentId = keccak256(abi.encode(intent));
        IntentState state = intentStates[intentId];
        if (state != IntentState.Solved && state != IntentState.Active)
            revert IntentHandler__InvalidState();
        if (intentSolvers[intentId] != msg.sender)
            revert IntentHandler__UnauthorizedCaller();

        intentStates[intentId] = IntentState.SolverResigned;

        // Get the solver's bond amount and slash bond (50% penalty)
        // todo: handle it nicely :)
        uint256 solverBondAmount = intentBondFactory.getSolverBondAmount(
            msg.sender
        );
        uint256 slashAmount = solverBondAmount / 2;

        // Slash the bond via the factory
        intentBondFactory.slashBond(msg.sender, slashAmount);

        emit IntentResignedBySolver(
            intent.user,
            msg.sender,
            slashAmount,
            intent.targetYield
        );
    }

    /*//////////////////////////////////////////////////////////////
                                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function addSolverEscrow(
        address solver,
        address asset
    ) external onlyKeeper {
        if (address(solverEscrows[solver]) != address(0))
            revert IntentHandler__SolverEscrowAlreadyExists();

        // Deploy new escrow for this solver
        Escrow escrow = new Escrow(address(this));

        solverEscrows[solver] = escrow;

        emit SolverEscrowAdded(solver, address(escrow), asset);
    }

    function removeSolverEscrow(address solver) external onlyKeeper {
        if (address(solverEscrows[solver]) == address(0))
            revert IntentHandler__SolverEscrowNotFound();

        delete solverEscrows[solver];

        emit SolverEscrowRemoved(solver);
    }

    function withdrawToken(address token, uint256 amount) external onlyKeeper {
        if (token == address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            if (!success) revert IntentHandler__WithdrawFailed();
        }
        IERC20(token).safeTransfer(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event SolverEscrowAdded(
        address indexed solver,
        address indexed escrow,
        address indexed asset
    );
    event SolverEscrowRemoved(address indexed solver);

    function hasCommitted(
        Intent memory intent
    )
        external
        view
        onlyExistingIntent(intent)
        returns (uint256 requiredNotional, uint256 arkAssets, bool isCommited)
    {
        bytes32 intentId = keccak256(abi.encode(intent));
        IntentState state = intentStates[intentId];

        if (state != IntentState.Solved) return (0, 0, false);
        requiredNotional = intent.requiredNotional;
        bool isInBufferZone = block.timestamp - intentSolveTime[intentId] <
            BUFFER_TIME;
        if (isInBufferZone) return (requiredNotional, 0, false);

        IArk ark = IArk(intent.user);
        arkAssets = ark.totalAssets();
        if (arkAssets < requiredNotional)
            return (requiredNotional, arkAssets, false);
        return (requiredNotional, arkAssets, true);
    }

    modifier onlyExistingIntent(Intent memory intent) {
        bytes32 intentId = keccak256(abi.encode(intent));
        if (intentStates[intentId] == IntentState.None)
            revert IntentHandler__IntentNotFound();
        _;
    }
    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error IntentHandler__SolverEscrowAlreadyExists();
    error IntentHandler__SolverEscrowNotFound();
    error IntentHandler__WithdrawFailed();
}
