// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SolverBond} from "./SolverBond.sol";
import {ProtocolAccessManaged} from "@summerfi/access-contracts/contracts/ProtocolAccessManaged.sol";
import {IIntentOracle} from "../interfaces/IIntentOracle.sol";

/**
 * @title IntentBondFactory
 * @notice Factory contract that creates individual bond contracts for each solver
 * @dev Each solver gets their own bond contract for complete isolation
 */
contract IntentBondFactory is ProtocolAccessManaged {
    /// @notice The number of decimals for the Summer token
    uint256 public constant SUMMER_TOKEN_DECIMALS = 18;
    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Summer token used for all bonds
    address public immutable summerToken;
    address public intentHandler;

    /// @notice The address of the price oracle used to value Summer token bonds
    address public oracle;

    /// @notice Mapping of solver addresses to their bond contracts
    mapping(address => address) public solverBonds;

    /// @notice Array of all created bond contracts
    address[] public allBonds;

    /*//////////////////////////////////////////////////////////////
                                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new bond contract is created for a solver
    /// @param solver Address of the solver
    /// @param bondContract Address of the created bond contract
    event BondCreated(address indexed solver, address indexed bondContract);

    /// @notice Emitted when a bond contract is removed for a solver
    /// @param solver Address of the solver
    /// @param bondContract Address of the removed bond contract
    event BondRemoved(address indexed solver, address indexed bondContract);

    /// @notice Emitted when a new oracle address is set
    /// @param oracle Address of the new oracle
    event OracleSet(address indexed oracle);

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address _summerToken,
        address _accessManager,
        address _oracle
    ) ProtocolAccessManaged(_accessManager) {
        if (_summerToken == address(0)) {
            revert IntentBondFactory__InvalidAddress(
                "summer token cannot be zero address"
            );
        }
        if (_accessManager == address(0)) {
            revert IntentBondFactory__InvalidAddress(
                "access manager cannot be zero address"
            );
        }
        if (_oracle == address(0)) {
            revert IntentBondFactory__InvalidAddress(
                "oracle cannot be zero address"
            );
        }
        summerToken = _summerToken;
        oracle = _oracle;
        emit OracleSet(oracle);
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new bond contract for a solver
     * @param solver Address of the solver
     * @return bondContract Address of the created bond contract
     */
    function createBond(
        address solver
    ) external onlyKeeper returns (address bondContract) {
        if (solver == address(0)) revert IntentBondFactory__InvalidSolver();
        if (solverBonds[solver] != address(0)) {
            revert IntentBondFactory__BondAlreadyExists();
        }

        // Deploy new bond contract for this solver
        bondContract = address(new SolverBond(solver, summerToken));

        // Record the bond contract
        solverBonds[solver] = bondContract;
        allBonds.push(bondContract);

        emit BondCreated(solver, bondContract);
    }

    /**
     * @notice Get the bond contract for a solver
     * @param solver Address of the solver
     * @return Address of the bond contract (address(0) if not created)
     */
    function getSolverBond(address solver) external view returns (address) {
        return solverBonds[solver];
    }

    /**
     * @notice Check if a solver has a bond contract
     * @param solver Address of the solver
     * @return True if solver has a bond contract
     */
    function hasBond(address solver) external view returns (bool) {
        return solverBonds[solver] != address(0);
    }

    /**
     * @notice Check if a solver is vouched (has sufficient bond)
     * @param solver Address of the solver
     * @param requiredBond Required bond amount in USD (18 decimals)
     * @return True if solver is vouched with sufficient bond
     * @dev This function converts USD amount to SUMR token amount using oracle price
     * @dev Formula: requiredAmount = (requiredBond * price) / 10^SUMMER_TOKEN_DECIMALS
     */
    function isSolverVouched(
        address solver,
        uint256 requiredBond
    ) external view returns (bool) {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) return false;
        (uint256 currentPrice, , ) = IIntentOracle(oracle).getPrice(
            summerToken
        );
        uint256 requiredAmount = (requiredBond * currentPrice) /
            10 ** SUMMER_TOKEN_DECIMALS;

        return ISolverBond(bondContract).hasSufficientBond(requiredAmount);
    }

    /**
     * @notice Get the bond amount for a solver
     * @param solver Address of the solver
     * @return Bond amount (0 if no bond)
     */
    function getSolverBondAmount(
        address solver
    ) external view returns (uint256) {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) return 0;

        return ISolverBond(bondContract).getBondAmount();
    }

    /**
     * @notice Get the bond amount for a solver in USD
     * @param solver Address of the solver
     * @return Bond amount in USD (0 if no bond)
     */
    function getSolverBondAmountInUsd(
        address solver
    ) external view returns (uint256) {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) return 0;
        (uint256 currentPrice, , ) = IIntentOracle(oracle).getPrice(
            summerToken
        );
        return
            (ISolverBond(bondContract).getBondAmount() * currentPrice) /
            10 ** SUMMER_TOKEN_DECIMALS;
    }

    /**
     * @notice Get all bond contracts
     * @return Array of all bond contract addresses
     */
    function getAllBonds() external view returns (address[] memory) {
        return allBonds;
    }

    /**
     * @notice Get total number of bond contracts
     * @return Total count of bond contracts
     */
    function getBondCount() external view returns (uint256) {
        return allBonds.length;
    }

    /**
     * @notice Get all vouched solvers (solvers with bonds)
     * @return Array of all solver addresses that have bonds
     */
    function getVouchedSolvers() external view returns (address[] memory) {
        address[] memory vouchedSolvers = new address[](allBonds.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allBonds.length; i++) {
            address bondContract = allBonds[i];
            // Find the solver for this bond contract
            for (uint256 j = 0; j < allBonds.length; j++) {
                if (solverBonds[address(uint160(j))] == bondContract) {
                    vouchedSolvers[count] = address(uint160(j));
                    count++;
                    break;
                }
            }
        }

        // Resize array to actual count
        assembly {
            mstore(vouchedSolvers, count)
        }

        return vouchedSolvers;
    }

    /**
     * @notice Get the total number of vouched solvers
     * @return Total count of vouched solvers
     */
    function getVouchedSolverCount() external view returns (uint256) {
        return allBonds.length;
    }

    /*//////////////////////////////////////////////////////////////
                                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Remove a bond contract (admin only, emergency use)
     * @param solver Address of the solver
     */
    function removeBond(address solver) external onlyKeeper {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) {
            revert IntentBondFactory__BondNotFound();
        }

        // Remove from mappings
        solverBonds[solver] = address(0);

        // Remove from array (replace with last element and pop)
        for (uint256 i = 0; i < allBonds.length; i++) {
            if (allBonds[i] == bondContract) {
                allBonds[i] = allBonds[allBonds.length - 1];
                allBonds.pop();
                break;
            }
        }

        emit BondRemoved(solver, bondContract);
    }

    /**
     * @notice Slashes a solver's bond contract by a specified amount (only callable by the intent handler)
     * @param solver The address of the solver whose bond should be slashed
     * @param slashAmount The amount of tokens to slash
     */
    function slashBond(
        address solver,
        uint256 slashAmount
    ) external onlyIntentHandler {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) {
            revert IntentBondFactory__BondNotFound();
        }

        ISolverBond(bondContract).slashBond(slashAmount);
    }

    /**
     * @notice Sets the address of the IntentHandler contract (can only be set once)
     * @param _intentHandler The address of the IntentHandler contract
     */
    function setIntentHandler(address _intentHandler) external {
        if (intentHandler != address(0)) {
            revert IntentBondFactory__IntentHandlerAlreadySet();
        }
        intentHandler = _intentHandler;
    }

    /// @notice Modifier to restrict function access to only the designated IntentHandler contract
    modifier onlyIntentHandler() {
        if (msg.sender != intentHandler) {
            revert IntentBondFactory__NotIntentHandler();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the solver address is invalid
    error IntentBondFactory__InvalidSolver();

    /// @notice Thrown when attempting to create a bond contract that already exists
    error IntentBondFactory__BondAlreadyExists();

    /// @notice Thrown when the bond contract for a solver cannot be found
    error IntentBondFactory__BondNotFound();

    /// @notice Thrown when attempting to set the intent handler address after it has already been set
    error IntentBondFactory__IntentHandlerAlreadySet();

    /// @notice Thrown when a caller is not the authorized IntentHandler contract
    error IntentBondFactory__NotIntentHandler();

    /// @notice Thrown when an input address parameters is invalid (e.g. zero address)
    /// @param message Reason describing why the address is invalid
    error IntentBondFactory__InvalidAddress(string message);
}

/**
 * @title ISolverBond
 * @notice Interface for individual solver bond contracts managed by the factory
 */
interface ISolverBond {
    /**
     * @notice Checks if the bond has a sufficient amount of tokens deposited
     * @param requiredAmount The amount of tokens required
     * @return True if the bond is sufficient, false otherwise
     */
    function hasSufficientBond(
        uint256 requiredAmount
    ) external view returns (bool);

    /**
     * @notice Gets the total amount of tokens currently bonded
     * @return The total amount of bonded tokens
     */
    function getBondAmount() external view returns (uint256);

    /**
     * @notice Slashes a specified amount from the bond
     * @param slashAmount The amount of tokens to slash
     */
    function slashBond(uint256 slashAmount) external;
}
