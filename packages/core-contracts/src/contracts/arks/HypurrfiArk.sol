// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {HypurrfiDataTypes} from "../../interfaces/hypurrfi/HypurrfiDataTypes.sol";
import {IHypurrfiPool} from "../../interfaces/hypurrfi/IHypurrfiPool.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "../Ark.sol";

/**
 * @title HypurrfiArk
 * @notice Ark contract for managing token supply and yield generation through Hypurrfi.
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Hypurrfi.
 *      Hypurrfi is a fork of Aave V3 with some modifications, includiung Frax v3 isolated lending pools.
 */
contract HypurrfiArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Hypurrfi aToken address
    address public immutable aToken;
    /// @notice The Hypurrfi pool address
    IHypurrfiPool public immutable hypurrfiPool;
    /// @notice The Hypurrfi rewards controller address
    IRewardsController public immutable rewardsController;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for HypurrfiArk
     * @param _hypurrfiPool Address of the Hypurrfi pool
     * @param _rewardsController Address of the Hypurrfi rewards controller
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _hypurrfiPool,
        address _rewardsController,
        ArkParams memory _params
    ) Ark(_params) {
        hypurrfiPool = IHypurrfiPool(_hypurrfiPool);
        HypurrfiDataTypes.ReserveData memory reserveData = hypurrfiPool
            .getReserveData(address(config.asset));
        aToken = reserveData.aTokenAddress;
        rewardsController = IRewardsController(_rewardsController);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256 assets) {
        assets = IERC20(aToken).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal function to get the total assets that are withdrawable
     * @dev HypurrfiArk is withdrawable if the asset is active, not frozen, and not paused
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 configData = hypurrfiPool
            .getReserveData(address(config.asset))
            .configuration
            .data;
        // We dont check if asset is frozen as
        // Withdrawals and repayments on the assets frozen are completely active, together with liquidations.
        // Only “additive” actions like supplying and borrowing them are halted.
        if (!(_isActive(configData) && !_isPaused(configData))) {
            return 0;
        }
        uint256 _totalAssets = totalAssets();
        if (_totalAssets == 0) {
            return 0;
        }
        uint256 assetsInAToken = config.asset.balanceOf(aToken);
        withdrawableAssets = assetsInAToken < _totalAssets
            ? assetsInAToken
            : _totalAssets;
    }

    /**
     * @notice Harvests rewards from the Aave V3 pool
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
        incentivizedAssets[0] = aToken;

        (rewardTokens, rewardAmounts) = rewardsController.claimAllRewards(
            incentivizedAssets,
            raft()
        );

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Boards the Ark by supplying the specified amount of tokens to the Aave V3 pool
     * @param amount Amount of tokens to supply
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.asset.forceApprove(address(hypurrfiPool), amount);
        hypurrfiPool.supply(address(config.asset), amount, address(this), 0);
    }

    /**
     * @notice Disembarks the Ark by withdrawing the specified amount of tokens from the Aave V3 pool
     * @param amount Amount of tokens to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        hypurrfiPool.withdraw(address(config.asset), amount, address(this));
    }

    /**
     * @notice Validates the board data
     * @dev Aave V3 Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata ta) internal override {
        // no-op
    }

    /**
     * @notice Validates the disembark data
     * @dev Aave V3 Ark does not require any validation for board or disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {
        // no-op
    }

    /// HELPERS

    /**
     * @notice Checks if the reserve is active based on the configuration data
     *
     * @param configData The configuration data of the reserve
     *
     * @return True if the reserve is active, false otherwise
     *
     * @dev A pool can be active or not in the normal lifecycle of the protocol
     */
    function _isActive(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.ACTIVE_MASK != 0;
    }

    /**
     * @notice Checks if the reserve is paused based on the configuration data
     *
     * @param configData The configuration data of the reserve
     *
     * @return True if the reserve is paused, false otherwise
     *
     * @dev A pool can be paused by the Aave governance to stop all actions on the reserve in case of an emergency
     */
    function _isPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.PAUSED_MASK != 0;
    }
}
