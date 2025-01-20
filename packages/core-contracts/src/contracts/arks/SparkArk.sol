// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "../Ark.sol";

/**
 * @title SparkArk
 * @notice Ark contract for managing token supply and yield generation through Spark Protocol (Aave V3 fork).
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Spark.
 */
contract SparkArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Spark spToken address (equivalent to aToken in Aave)
    address public immutable spToken;
    /// @notice The Spark pool address
    IPoolV3 public immutable sparkPool;
    /// @notice The Spark rewards controller address
    IRewardsController public immutable rewardsController;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for SparkArk
     * @param _sparkPool Address of the Spark pool
     * @param _rewardsController Address of the Spark rewards controller
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _sparkPool,
        address _rewardsController,
        ArkParams memory _params
    ) Ark(_params) {
        sparkPool = IPoolV3(_sparkPool);
        DataTypes.ReserveData memory reserveData = sparkPool.getReserveData(
            address(config.asset)
        );
        spToken = reserveData.aTokenAddress; // In Spark, aToken is called spToken
        rewardsController = IRewardsController(_rewardsController);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = IERC20(spToken).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev SparkArk is withdrawable if the asset is active, not frozen, and not paused
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 configData = sparkPool
            .getReserveData(address(config.asset))
            .configuration
            .data;
        // We dont check if asset is frozen as
        // Withdrawals and repayments on the assets frozen are completely active, together with liquidations.
        // Only "additive" actions like supplying and borrowing them are halted.
        if (!(_isActive(configData) && !_isPaused(configData))) {
            return 0;
        }
        uint256 _totalAssets = totalAssets();
        if (_totalAssets == 0) {
            return 0;
        }
        uint256 assetsInSpToken = config.asset.balanceOf(spToken);
        withdrawableAssets = assetsInSpToken < _totalAssets
            ? assetsInSpToken
            : _totalAssets;
    }

    /**
     * @notice Harvests rewards from the Spark pool
     * @param /// data Additional data for the harvest operation
     * @return rewardTokens Array of reward tokens
     * @return rewardAmounts Array of reward amounts
     */
    function _harvest(
        bytes calldata
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = spToken;

        (rewardTokens, rewardAmounts) = rewardsController.claimAllRewards(
            incentivizedAssets,
            raft()
        );

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Boards the Ark by supplying the specified amount of tokens to the Spark pool
     * @param amount Amount of tokens to supply
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(sparkPool), amount);
        sparkPool.supply(address(config.asset), amount, address(this), 0);
    }

    /**
     * @notice Disembarks the Ark by withdrawing the specified amount of tokens from the Spark pool
     * @param amount Amount of tokens to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        sparkPool.withdraw(address(config.asset), amount, address(this));
    }

    /**
     * @notice Validates the board data
     * @dev Spark Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev Spark Ark does not require any validation for disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {}

    function _isActive(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.ACTIVE_MASK != 0;
    }

    function _isPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.PAUSED_MASK != 0;
    }
}
