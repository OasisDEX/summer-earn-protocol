// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IPoolV3} from "../../src/interfaces/aave-v3/IPoolV3.sol";

contract MockAavePool is IPoolV3 {
    mapping(address => uint256) public balances;

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 /*referralCode*/
    ) external override {
        require(asset != address(0), "Invalid asset address");
        require(amount > 0, "Amount must be greater than zero");
        require(onBehalfOf != address(0), "Invalid onBehalfOf address");

        balances[asset] += amount;
    }
}