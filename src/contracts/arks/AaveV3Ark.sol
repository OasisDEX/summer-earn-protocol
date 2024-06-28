// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";

contract AaveV3Ark is Ark {
    IPoolV3 public aaveV3Pool;
    event Board(address indexed token, uint256 amount, address indexed onBehalfOf);

    constructor(address _aaveV3Pool, ArkParams memory _params) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
    }

    function board(uint256 amount) external override onlyCommander {
        aaveV3Pool.supply(address(token), amount, address(this), 0);
    }

    function disembark(uint256 amount) external override onlyCommander {}
    function move(uint256 amount, address newArk) external override onlyCommander {}
}
