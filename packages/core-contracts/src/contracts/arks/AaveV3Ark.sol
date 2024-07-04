// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IPoolV3} from "../../interfaces/aave-v3/IPoolV3.sol";
import {IArk} from "../../interfaces/IArk.sol";

contract AaveV3Ark is Ark {
    IPoolV3 public aaveV3Pool;

    constructor(address _aaveV3Pool, ArkParams memory _params) Ark(_params) {
        aaveV3Pool = IPoolV3(_aaveV3Pool);
    }

    function _board(uint256 amount) internal override {
        aaveV3Pool.supply(address(token), amount, address(this), 0);
    }

    function _disembark(uint256 amount) internal override {
        aaveV3Pool.withdraw(address(token), amount, msg.sender);
    }
}
