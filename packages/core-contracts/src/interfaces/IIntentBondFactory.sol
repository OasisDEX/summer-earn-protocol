// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

/**
 * @title IIntentBondFactory
 * @notice Interface for the intent bond factory contract that creates individual bond contracts for each solver
 */
interface IIntentBondFactory {
    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event BondCreated(address indexed solver, address indexed bondContract);
    event BondRemoved(address indexed solver, address indexed bondContract);

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidSolver();
    error BondAlreadyExists();
    error BondNotFound();

    /*//////////////////////////////////////////////////////////////
                                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Create a new bond contract for a solver
     * @param solver Address of the solver
     * @return bondContract Address of the created bond contract
     */
    function createBond(address solver) external returns (address bondContract);

    /**
     * @notice Get the bond contract for a solver
     * @param solver Address of the solver
     * @return Address of the bond contract (address(0) if not created)
     */
    function getSolverBond(address solver) external view returns (address);

    /**
     * @notice Check if a solver has a bond contract
     * @param solver Address of the solver
     * @return True if solver has a bond contract
     */
    function hasBond(address solver) external view returns (bool);

    /**
     * @notice Check if a solver is vouched (has sufficient bond)
     * @param solver Address of the solver
     * @param requiredAmount Required bond amount
     * @return True if solver is vouched with sufficient bond
     */
    function isSolverVouched(
        address solver,
        uint256 requiredAmount
    ) external view returns (bool);

    /**
     * @notice Get the bond amount for a solver
     * @param solver Address of the solver
     * @return Bond amount (0 if no bond)
     */
    function getSolverBondAmount(
        address solver
    ) external view returns (uint256);

    /**
     * @notice Get all bond contracts
     * @return Array of all bond contract addresses
     */
    function getAllBonds() external view returns (address[] memory);

    /**
     * @notice Get total number of bond contracts
     * @return Total count of bond contracts
     */
    function getBondCount() external view returns (uint256);

    /**
     * @notice Get all vouched solvers (solvers with bonds)
     * @return Array of all solver addresses that have bonds
     */
    function getVouchedSolvers() external view returns (address[] memory);

    /**
     * @notice Get the total number of vouched solvers
     * @return Total count of vouched solvers
     */
    function getVouchedSolverCount() external view returns (uint256);

    /**
     * @notice Get the Summer token address used for all bonds
     * @return Address of the Summer token
     */
    function summerToken() external view returns (address);
}
