// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {ArkAccessManaged} from "../ArkAccessManaged.sol";
import {GenericIntentArk} from "../arks/GenericIntentArk.sol";
import {IAdapter} from "../../interfaces/intents/IAdapter.sol";

/**
 * @title AaveV3Adapter
 * @notice Adapter for Aave V3 protocol interactions
 * @dev Handles supply, withdraw, and reward claiming for Aave V3
 *      Uses ArkAccessManaged for access control through the GenericIntentArk
 * @dev end goal : make it erc4626 - can be used outside summer
 */
contract AaveV3Adapter is ArkAccessManaged, ReentrancyGuard, IAdapter {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                                    STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Aave V3 Pool contract
    IPoolV3 public immutable aaveV3Pool;

    /// @notice Aave V3 Rewards Controller
    IRewardsController public immutable rewardsController;

    /// @notice The GenericIntentArk that this adapter works with
    GenericIntentArk public immutable ark;

    /*//////////////////////////////////////////////////////////////
                                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    modifier onlyIntentHandler() {
        if (msg.sender != address(ark.intentHandler()))
            revert UnauthorizedCaller();
        _;
    }
    constructor(
        address _accessManager,
        address _aaveV3Pool,
        address _rewardsController,
        address _ark
    ) ArkAccessManaged(_accessManager) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        rewardsController = IRewardsController(_rewardsController);
        ark = GenericIntentArk(_ark);
    }

    /*//////////////////////////////////////////////////////////////
                                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Supply assets to Aave V3
     * @param asset Asset to supply
     * @param amount Amount to supply
     * @param onBehalfOf Address to supply on behalf of
     */
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf // todo: remove this
    ) external onlyIntentHandler nonReentrant {
        // Approve Aave to spend the asset
        IERC20(asset).forceApprove(address(aaveV3Pool), amount);

        // Supply to Aave
        aaveV3Pool.supply(asset, amount, address(this), 0);
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
        address to // todo: remove this
    ) external onlyIntentHandler nonReentrant {
        aaveV3Pool.withdraw(asset, amount, address(this));
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
        onlyKeeper
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
                                        ERRORS
    //////////////////////////////////////////////////////////////*/

    error UnauthorizedCaller();
}
