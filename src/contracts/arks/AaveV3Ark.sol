// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "../Ark.sol";

contract AaveV3Ark is BaseArk {
    constructor(ArkParams memory params) BaseArk(params) {}

    function board(uint256 amount) external override onlyCommander {}
    function disembark(uint256 amount) external override onlyCommander {}
    function move(uint256 amount, address newArk) external override onlyCommander {}
}