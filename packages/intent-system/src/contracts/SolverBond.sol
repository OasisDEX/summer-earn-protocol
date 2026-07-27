// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title SolverBond
 * @notice Individual bond contract for a single solver
 * @dev Each solver has their own bond contract for complete isolation
 */
contract SolverBond is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The solver who owns this bond
    address public immutable solver;

    /// @notice The address of the factory contract that deployed this bond
    address public immutable factory;

    /// @notice The Summer token used for bonding
    IERC20 public immutable summerToken;

    /// @notice Total amount of Summer tokens bonded
    uint256 public totalBonded;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solver, address _summerToken) {
        if (_solver == address(0)) {
            revert SolverBond__InvalidAddress("solver cannot be zero address");
        }
        if (_summerToken == address(0)) {
            revert SolverBond__InvalidAddress(
                "summer token cannot be zero address"
            );
        }
        solver = _solver;
        summerToken = IERC20(_summerToken);
        factory = msg.sender;
    }

    /*//////////////////////////////////////////////////////////////
                                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySolver() {
        if (msg.sender != solver) revert SolverBond__UnauthorizedCaller();
        _;
    }

    /// @notice Modifier that restricts access to only the factory contract
    modifier onlyFactory() {
        if (msg.sender != factory) revert SolverBond__UnauthorizedCaller();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Add Summer tokens to the bond
     * @param amount Amount of Summer tokens to add
     */
    function addBond(uint256 amount) external onlySolver nonReentrant {
        if (amount == 0) revert SolverBond__InvalidAmount();

        // Transfer Summer tokens from solver to this contract
        summerToken.safeTransferFrom(solver, address(this), amount);

        // Update bond amount
        totalBonded += amount;

        emit BondAdded(solver, amount, totalBonded);
    }

    /**
     * @notice Remove Summer tokens from the bond
     * @param amount Amount of Summer tokens to remove
     */
    function removeBond(uint256 amount) external onlySolver nonReentrant {
        if (amount == 0) revert SolverBond__InvalidAmount();
        if (amount > totalBonded) revert SolverBond__InsufficientBond();

        // Update bond amount
        totalBonded -= amount;

        // Transfer Summer tokens back to solver
        summerToken.safeTransfer(solver, amount);

        emit BondRemoved(solver, amount, totalBonded);
    }

    /**
     * @notice Slash the bond (can only be called by liquidator)
     * @param slashAmount Amount to slash from the bond
     */
    function slashBond(uint256 slashAmount) external onlyFactory {
        if (slashAmount == 0) revert SolverBond__InvalidAmount();
        if (slashAmount > totalBonded) revert SolverBond__InsufficientBond();

        // Update bond amount
        totalBonded -= slashAmount;
        summerToken.safeTransfer(factory, slashAmount);

        emit BondSlashed(solver, slashAmount, totalBonded);
    }

    /*//////////////////////////////////////////////////////////////
                                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Get the current bond amount
     * @return Current bond amount
     */
    function getBondAmount() external view returns (uint256) {
        return totalBonded;
    }

    /**
     * @notice Check if bond has sufficient amount
     * @param requiredAmount Required amount
     * @return True if bond is sufficient
     */
    function hasSufficientBond(
        uint256 requiredAmount
    ) external view returns (bool) {
        return totalBonded >= requiredAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a solver adds tokens to their bond
    /// @param solver Address of the solver
    /// @param amount Amount of tokens added
    /// @param totalBonded Total amount of tokens now bonded
    event BondAdded(
        address indexed solver,
        uint256 amount,
        uint256 totalBonded
    );

    /// @notice Emitted when a solver removes tokens from their bond
    /// @param solver Address of the solver
    /// @param amount Amount of tokens removed
    /// @param totalBonded Total amount of tokens now bonded
    event BondRemoved(
        address indexed solver,
        uint256 amount,
        uint256 totalBonded
    );

    /// @notice Emitted when the bond is slashed
    /// @param solver Address of the solver whose bond was slashed
    /// @param slashAmount Amount of tokens slashed
    /// @param remainingBond Remaining amount of tokens bonded
    event BondSlashed(
        address indexed solver,
        uint256 slashAmount,
        uint256 remainingBond
    );

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the caller is not authorized to perform the operation
    error SolverBond__UnauthorizedCaller();

    /// @notice Thrown when the specified token amount is invalid (e.g. zero)
    error SolverBond__InvalidAmount();

    /// @notice Thrown when the solver has an insufficient bond balance for the operation
    error SolverBond__InsufficientBond();

    /// @notice Thrown when an input address parameters is invalid (e.g. zero address)
    /// @param message Reason describing why the address is invalid
    error SolverBond__InvalidAddress(string message);
}
