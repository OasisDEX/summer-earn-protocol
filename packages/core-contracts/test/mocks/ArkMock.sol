// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ark, ArkParams} from "../../src/contracts/Ark.sol";
import {IArk} from "../../src/interfaces/IArk.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArkMock is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function rate() public view override returns (uint256) {
        // Mock implementation, returns a fixed rate
        return 1e24;
    }

    function totalAssets() public view override returns (uint256) {
        // Mock implementation, returns the total token balance of this contract
        return IERC20(token).balanceOf(address(this));
    }

    function _board(uint256 amount) internal override {}

    function _disembark(uint256 amount) internal override {}
}
