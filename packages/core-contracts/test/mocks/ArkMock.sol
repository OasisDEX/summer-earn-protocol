// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {Ark, ArkParams} from "../../src/contracts/Ark.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArkMock is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function totalAssets() public view override returns (uint256) {
        // Mock implementation, returns the total token balance of this contract
        return IERC20(config.token).balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata data) internal override {}

    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override {}

    function _harvest(
        address rewardToken,
        bytes calldata data
    ) internal override returns (uint256) {
        uint256 amount = abi.decode(data, (uint256));
        IERC20(rewardToken).transfer(msg.sender, amount);
        return amount;
    }
    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
