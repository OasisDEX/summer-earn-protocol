// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SolverBond} from "./SolverBond.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IntentBondFactory
 * @notice Factory contract that creates individual bond contracts for each solver
 * @dev Each solver gets their own bond contract for complete isolation
 */
contract IntentBondFactory is AccessControl {
    /*//////////////////////////////////////////////////////////////
                                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The Summer token used for all bonds
    address public immutable summerToken;

    /// @notice Mapping of solver addresses to their bond contracts
    mapping(address => address) public solverBonds;

    /// @notice Array of all created bond contracts
    address[] public allBonds;

    /*//////////////////////////////////////////////////////////////
                                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event BondCreated(address indexed solver, address indexed bondContract);
    event BondRemoved(address indexed solver, address indexed bondContract);

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _summerToken) {
        summerToken = _summerToken;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
    ) external returns (address bondContract) {
        if (solver == address(0)) revert InvalidSolver();
        if (solverBonds[solver] != address(0)) revert BondAlreadyExists();

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
     * @param requiredAmount Required bond amount
     * @return True if solver is vouched with sufficient bond
     */
    function isSolverVouched(
        address solver,
        uint256 requiredAmount
    ) external view returns (bool) {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) return false;

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

    function grantHandlerRole(
        address handler
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(HANDLER_ROLE, handler);
    }

    function grantLiquidatorRole(
        address liquidator
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(LIQUIDATOR_ROLE, liquidator);
    }

    /**
     * @notice Remove a bond contract (admin only, emergency use)
     * @param solver Address of the solver
     */
    function removeBond(address solver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address bondContract = solverBonds[solver];
        if (bondContract == address(0)) revert BondNotFound();

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

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidSolver();
    error BondAlreadyExists();
    error BondNotFound();
}

// Interface for individual solver bond contracts
interface ISolverBond {
    function hasSufficientBond(
        uint256 requiredAmount
    ) external view returns (bool);
    function getBondAmount() external view returns (uint256);
    function slashBond(uint256 slashAmount) external;
}
