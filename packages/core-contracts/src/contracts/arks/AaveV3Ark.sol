// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ark} from "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {DataTypes} from "../../interfaces/aave-v3/DataTypes.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IRewardsController} from "../../interfaces/aave-v3/IRewardsController.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IArk, ArkParams} from "../../interfaces/IArk.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveV3Ark is Ark {
    using SafeERC20 for IERC20;
    uint256 public constant WAD = 1e18;
    uint256 public constant RAY = 1e27;
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    IPoolV3 public aaveV3Pool;
    IPoolDataProvider public aaveV3DataProvider;
    address public aToken;
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
            address(token)
        );
        aToken = reserveData.aTokenAddress;
        rewardsController = IRewardsController(_rewardsController);
    }

    function rate() public view override returns (uint256) {
        (, , , , , uint256 liquidityRate, , , , , , ) = aaveV3DataProvider
            .getReserveData(address(token));
        return liquidityRate;
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    function _harvest(address rewardToken, bytes) internal override returns (uint256) {
        (, address aTokenAddress, ) = aaveV3DataProvider
            .getReserveTokensAddresses(address(token));
        address[] memory incentivizedAssets = new address[](1);
        incentivizedAssets[0] = aTokenAddress;

        uint256 claimedRewardsBalance = rewardsController.claimRewardsToSelf(
            incentivizedAssets,
            type(uint256).max,
            rewardToken
        );
        IERC20(rewardToken).safeTransfer(raft, claimedRewardsBalance);

        emit Harvested(claimedRewardsBalance);

        return claimedRewardsBalance;
    }

    function _board(uint256 amount) internal override {
        token.approve(address(aaveV3Pool), amount);
        aaveV3Pool.supply(address(token), amount, address(this), 0);
    }

    function _disembark(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(token), amount, address(this));
    }
}
