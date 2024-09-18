// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";

import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";

import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import "../Ark.sol";

contract AaveV3Ark is Ark {
    using SafeERC20 for IERC20;

    address public aToken;
    IPoolV3 public aaveV3Pool;
    IPoolDataProvider public aaveV3DataProvider;
    IRewardsController public rewardsController;

    struct RewardsData {
        address rewardToken;
    }

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

    function rate() public view override returns (uint256) {
        (, , , , , uint256 liquidityRate, , , , , , ) = aaveV3DataProvider
            .getReserveData(address(config.token));
        return liquidityRate;
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

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

    function _board(uint256 amount, bytes calldata) internal override {
        config.token.approve(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(config.token), amount, address(this), 0);
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        aaveV3Pool.withdraw(address(config.token), amount, address(this));
    }

    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
