// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";

contract AaveV3Ark is Ark {
    using SafeERC20 for IERC20;

    address public aToken;
    IPoolV3 public aaveV3Pool;
    IPoolDataProvider public aaveV3DataProvider;
    IRewardsController public rewardsController;

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

    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    function _harvest(
        address rewardToken,
        bytes calldata
    ) internal override returns (uint256 claimedRewardsBalance) {
        (, address aTokenAddress, ) = aaveV3DataProvider
            .getReserveTokensAddresses(address(config.token));
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = aTokenAddress;

        claimedRewardsBalance = rewardsController.claimRewardsToSelf(
            incentivizedAssets,
            type(uint256).max,
            rewardToken
        );
        IERC20(rewardToken).safeTransfer(config.raft, claimedRewardsBalance);

        emit Harvested(claimedRewardsBalance);
    }

    function _board(uint256 amount) internal override {
        config.token.approve(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(config.token), amount, address(this), 0);
    }

    function _disembark(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(config.token), amount, address(this));
    }
}
