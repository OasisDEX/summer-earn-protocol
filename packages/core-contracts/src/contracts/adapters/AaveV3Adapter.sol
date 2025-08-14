// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";

/**
 * @title AaveV3Adapter
 * @notice Adapter for Aave V3 protocol interactions
 * @dev Handles supply, withdraw, and reward claiming for Aave V3
 */
contract AaveV3Adapter is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                        CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ARK_ROLE = keccak256("ARK_ROLE");
    bytes32 public constant SOLVER_ROLE = keccak256("SOLVER_ROLE");

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V3 Pool contract
    IPoolV3 public immutable aaveV3Pool;

    /// @notice Aave V3 Rewards Controller
    IRewardsController public immutable rewardsController;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _aaveV3Pool, address _rewardsController) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        rewardsController = IRewardsController(_rewardsController);
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

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Supply assets to Aave V3
     * @param asset Asset to supply
     * @param amount Amount to supply
     * @param onBehalfOf Address to supply on behalf of
     * @param referralCode Referral code (0 for none)
     */
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external onlyArk nonReentrant {
        // Approve Aave to spend the asset
        IERC20(asset).forceApprove(address(aaveV3Pool), amount);

        // Supply to Aave
        aaveV3Pool.supply(asset, amount, onBehalfOf, referralCode);
    }

    /**
     * @notice Withdraw assets from Aave V3
     * @param asset Asset to withdraw
     * @param amount Amount to withdraw
     * @param to Address to receive withdrawn assets
     */
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external onlyArk nonReentrant {
        aaveV3Pool.withdraw(asset, amount, to);
    }

    /**
     * @notice Claim all rewards from Aave V3
     * @param assets List of assets to check for rewards
     * @param user User address to claim rewards for
     * @return rewardTokens Array of reward token addresses
     * @return rewardAmounts Array of reward amounts
     */
    function claimAllRewards(
        address[] calldata assets,
        address user
    )
        external
        onlyArk
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        return rewardsController.claimAllRewards(assets, user);
    }

    /**
     * @notice Get the reserve data for an asset
     * @param asset Asset address
     * @return Reserve data struct
     */
    function getReserveData(
        address asset
    ) external view returns (DataTypes.ReserveData memory) {
        return aaveV3Pool.getReserveData(asset);
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

    /*//////////////////////////////////////////////////////////////
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnauthorizedCaller();
}
