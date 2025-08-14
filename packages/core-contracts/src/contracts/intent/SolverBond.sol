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
                                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant HANDLER_ROLE = keccak256("HANDLER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The solver who owns this bond
    address public immutable solver;

    /// @notice The Summer token used for bonding
    IERC20 public immutable summerToken;

    /// @notice Total amount of Summer tokens bonded
    uint256 public totalBonded;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _solver, address _summerToken) {
        solver = _solver;
        summerToken = IERC20(_summerToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlySolver() {
        if (msg.sender != solver) revert UnauthorizedCaller();
        _;
    }

    modifier onlyHandler() {
        if (!hasRole(HANDLER_ROLE, msg.sender)) revert UnauthorizedCaller();
        _;
    }

    modifier onlyLiquidator() {
        if (!hasRole(LIQUIDATOR_ROLE, msg.sender)) revert UnauthorizedCaller();
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
        if (amount == 0) revert InvalidAmount();

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
        if (amount == 0) revert InvalidAmount();
        if (amount > totalBonded) revert InsufficientBond();

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
    function slashBond(uint256 slashAmount) external onlyLiquidator {
        if (slashAmount == 0) revert InvalidAmount();
        if (slashAmount > totalBonded) revert InsufficientBond();

        // Update bond amount
        totalBonded -= slashAmount;

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

    /*//////////////////////////////////////////////////////////////
                                        EVENTS
    //////////////////////////////////////////////////////////////*/

    event BondAdded(
        address indexed solver,
        uint256 amount,
        uint256 totalBonded
    );
    event BondRemoved(
        address indexed solver,
        uint256 amount,
        uint256 totalBonded
    );
    event BondSlashed(
        address indexed solver,
        uint256 slashAmount,
        uint256 remainingBond
    );

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnauthorizedCaller();
    error InvalidAmount();
    error InsufficientBond();
}
