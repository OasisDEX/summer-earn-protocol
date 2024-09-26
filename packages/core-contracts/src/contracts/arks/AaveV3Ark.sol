// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";

import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";

import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "../Ark.sol";

/**
 * @title AaveV3Ark
 * @notice This contract manages a Aave V3 token strategy within the Ark system
 */
contract AaveV3Ark is Ark {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The Aave V3 aToken address
    address public aToken;
    /// @notice The Aave V3 pool address
    IPoolV3 public aaveV3Pool;
    /// @notice The Aave V3 data provider address
    IPoolDataProvider public aaveV3DataProvider;
    /// @notice The Aave V3 rewards controller address
    IRewardsController public rewardsController;

    /**
     * @notice Struct to hold reward token information
     * @param rewardToken The address of the reward token
     */
    struct RewardsData {
        address rewardToken;
    }

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor for AaveV3Ark
     * @param _aaveV3Pool Address of the Aave V3 pool
     * @param _rewardsController Address of the Aave V3 rewards controller
     * @param _params ArkParams struct containing initialization parameters
     */
    constructor(
        address _aaveV3Pool,
        address _rewardsController,
        ArkParams memory _params
    ) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        IPoolAddressesProvider aaveV3AddressesProvider = aaveV3Pool
            .ADDRESSES_PROVIDER();
        aaveV3DataProvider = IPoolDataProvider(
            aaveV3AddressesProvider.getPoolDataProvider()
        );
        DataTypes.ReserveData memory reserveData = aaveV3Pool.getReserveData(
            address(config.token)
        );
        aToken = reserveData.aTokenAddress;
        rewardsController = IRewardsController(_rewardsController);
    }

    /*//////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc IArk
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Harvests rewards from the Aave V3 pool
     * @param data Additional data for the harvest operation
     * @return rewardTokens Array of reward tokens
     * @return rewardAmounts Array of reward amounts
     */
    function _harvest(
        bytes calldata data
    )
        internal
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);

        RewardsData memory rewardsData = abi.decode(data, (RewardsData));
        rewardTokens[0] = rewardsData.rewardToken;

        (, address aTokenAddress, ) = aaveV3DataProvider
            .getReserveTokensAddresses(address(config.token));
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = aTokenAddress;

        rewardAmounts[0] = rewardsController.claimRewardsToSelf(
            incentivizedAssets,
            type(uint256).max,
            rewardsData.rewardToken
        );
        IERC20(rewardsData.rewardToken).safeTransfer(
            config.raft,
            rewardAmounts[0]
        );

        emit ArkHarvested(rewardTokens, rewardAmounts);
    }

    /**
     * @notice Boards the Ark by supplying the specified amount of tokens to the Aave V3 pool
     * @param amount Amount of tokens to supply
     */
    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(config.token), amount, address(this), 0);
    }

    /**
     * @notice Disembarks the Ark by withdrawing the specified amount of tokens from the Aave V3 pool
     * @param amount Amount of tokens to withdraw
     */
    function _disembark(uint256 amount, bytes calldata) internal override {
        aaveV3Pool.withdraw(address(config.token), amount, address(this));
    }

    /**
     * @notice Validates the board data
     * @dev Aave V3 Ark does not require any validation for board data
     */
    function _validateBoardData(bytes calldata ta) internal override {}

    /**
     * @notice Validates the disembark data
     * @dev Aave V3 Ark does not require any validation for board or disembark data
     */
    function _validateDisembarkData(bytes calldata) internal override {}
}
