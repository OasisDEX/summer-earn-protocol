// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";

contract AaveV3Ark is Ark {
    IPoolV3 public aavePool;

    constructor(address _aavePool, ArkParams memory _params) Ark(_params) {
        aavePool = IPoolV3(_aavePool);
    }

    function board(uint256 amount) external override onlyCommander {
        aavePool.supply(address(token), amount, address(this), 0);
    }

    function disembark(uint256 amount) external override onlyCommander {}
    function move(uint256 amount, address newArk) external override onlyCommander {}
}
