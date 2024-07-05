// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IArk} from "../../interfaces/IArk.sol";

contract AaveV3Ark is Ark {
    IPoolV3 public aaveV3Pool;
    IPoolDataProvider public aaveV3DataProvider;

    constructor(address _aaveV3Pool, ArkParams memory _params) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
        IPoolAddressesProvider aaveV3AddressesProvider = aaveV3Pool
            .ADDRESSES_PROVIDER();
        aaveV3DataProvider = IPoolDataProvider(
            aaveV3AddressesProvider.getPoolDataProvider()
        );
    }

    function rate() public view override returns (uint256) {
        (, , , , uint256 liquidityRate, , , , , , , ) = aaveV3DataProvider
            .getReserveData(address(token));
        return liquidityRate;
    }

    function totalAssets() public view override returns (uint256) {
        (uint256 currentATokenBalance, , , , , , , , ) = aaveV3DataProvider
            .getUserReserveData(address(token), address(this));
        return currentATokenBalance;
    }

    function _board(uint256 amount) internal override {
        aaveV3Pool.supply(address(token), amount, address(this), 0);
    }

    function _disembark(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(token), amount, msg.sender);
    }
}
