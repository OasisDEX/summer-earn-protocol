// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "../Ark.sol";
import "../../interfaces/IIntentHandler.sol";
import "../../interfaces/IIntentBondFactory.sol";

/**
 * @title AaveV3IntentArk
 * @notice Ark contract for managing token supply and yield generation through Aave V3 with intent-based bonds
 * @dev Implements strategy for supplying tokens, withdrawing tokens, and claiming rewards on Aave V3
 *      with integrated intent-based bond system for yield guarantees
 */
contract AaveV3IntentArk is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Aave V3 aToken address
    address public immutable aToken;
    /// @notice The Aave V3 pool address
    IPoolV3 public immutable aaveV3Pool;
    /// @notice The Aave V3 rewards controller address
    IRewardsController public immutable rewardsController;
    /// @notice The intent handler contract
    IIntentHandler public immutable intentHandler;
    /// @notice The intent bond factory contract
    IIntentBondFactory public immutable intentBondFactory;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for AaveV3IntentArk
     * @param _aaveV3Pool Address of the Aave V3 pool
     * @param _rewardsController Address of the Aave V3 rewards controller
     * @param _intentHandler Address of the intent handler contract
     * @param _intentBondFactory Address of the intent bond factory contract
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        address _intentHandler,
        address _intentBondFactory,
        ArkParams memory _params
    ) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        DataTypes.ReserveData memory reserveData = aaveV3Pool.getReserveData(
            address(config.asset)
        );
        aToken = reserveData.aTokenAddress;
        rewardsController = IRewardsController(_rewardsController);
        intentHandler = IIntentHandler(_intentHandler);
        intentBondFactory = IIntentBondFactory(_intentBondFactory);
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
     * @dev AaveV3IntentArk is withdrawable if the asset is active, not frozen, and not paused
     */
    function _withdrawableTotalAssets()
        internal
        view
        override
        returns (uint256 withdrawableAssets)
    {
        uint256 configData = aaveV3Pool
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
        uint256 assetsInAToken = config.asset.balanceOf(aToken);
        withdrawableAssets = assetsInAToken < _totalAssets
            ? assetsInAToken
            : _totalAssets;
    }

    /**
     * @notice Harvests rewards from the Aave V3 pool
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
        // Basic boarding - no intent data processing
        // Intents are created separately via createIntent() function

        config.asset.forceApprove(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(config.asset), amount, address(this), 0);
    }

    /**
     * @notice Disembarks the Ark by withdrawing the specified amount of tokens from the Aave V3 pool
     * @param amount Amount of tokens to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        aaveV3Pool.withdraw(address(config.asset), amount, address(this));
    }

    /**
     * @notice Validates the board data for intent-based operations
     * @param data Board data containing intent information
     */
    function _validateBoardData(bytes calldata data) internal view override {
        if (data.length > 0) {
            // Decode intent data and validate
            (
                uint256 requiredNotional,
                uint256 term,
                uint256 targetYield,
                address summerToken,
                address oracle,
                uint256 expiry
            ) = abi.decode(
                    data,
                    (uint256, uint256, uint256, address, address, uint256)
                );

            require(requiredNotional > 0, "Invalid notional");
            require(term > 0, "Invalid term");
            require(targetYield > 0, "Invalid yield");
            require(summerToken != address(0), "Invalid summer token");
            require(oracle != address(0), "Invalid oracle");
            require(expiry > block.timestamp, "Invalid expiry");
        }
    }

    /**
     * @notice Validates the disembark data
     * @dev Aave V3 Intent Ark does not require validation for disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {}

    /**
     * @notice Creates an intent for yield generation
     * @param requiredNotional Required notional value in Summer tokens
     * @param term Duration of the intent in seconds
     * @param targetYield Target yield amount
     * @param summerToken Summer token address for bonding
     * @param oracle Oracle address for price verification
     * @param expiry Expiry timestamp
     */
    function createIntent(
        uint256 requiredNotional,
        uint256 term,
        uint256 targetYield,
        address summerToken,
        address oracle,
        uint256 expiry
    ) external onlyCommander {
        intentHandler.createIntent(
            address(this),
            requiredNotional,
            term,
            targetYield,
            summerToken,
            oracle,
            expiry
        );
    }

    /**
     * @notice Accepts a match from a solver (legacy function - now solvers solve directly)
     * @param solverAddress Address of the solver
     * @param escrowedYield Amount of yield escrowed upfront
     * @dev This function is kept for backward compatibility but now calls solveIntent
     */
    function acceptMatch(
        address solverAddress,
        uint256 escrowedYield
    ) external onlyCommander {
        // In the new system, solvers solve intents directly
        // This function is kept for backward compatibility
        intentHandler.solveIntent(address(this), solverAddress, escrowedYield);
    }

    /**
     * @notice Activates an intent after matching
     */
    function activateIntent() external onlyCommander {
        intentHandler.activateIntent(address(this));
    }

    /**
     * @notice Settles a completed intent
     */
    function settleIntent() external onlyCommander {
        intentHandler.settleIntent(address(this));
    }

    /**
     * @notice Resigns the Ark intent
     */
    function resignIntent() external onlyCommander {
        intentHandler.resignByArk(address(this));
    }

    function _isActive(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.ACTIVE_MASK != 0;
    }

    function _isPaused(uint256 configData) internal pure returns (bool) {
        return configData & ~Constants.PAUSED_MASK != 0;
    }
}
