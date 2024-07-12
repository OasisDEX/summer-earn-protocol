// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ark, BaseArkParams} from "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IPoolDataProvider} from "../../interfaces/aave-v3/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "../../interfaces/aave-v3/IPoolAddressesProvider.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AaveV3Ark is Initializable, Ark {
    IPoolV3 public aaveV3Pool;
    IPoolDataProvider public aaveV3DataProvider;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        BaseArkParams memory params,
        bytes memory additionalParams
    ) public initializer {
        __Ark_init(params);
        address _aaveV3Pool = abi.decode(additionalParams, (address));

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
