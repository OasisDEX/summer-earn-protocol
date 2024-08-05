// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";

contract BufferArk is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function rate() public pure override returns (uint256) {
        return 0;
    }

    function totalAssets() public view override returns (uint256) {
        return token.balanceOf(address(this));
    }

    function _board(uint256 amount) internal override {}

    function _disembark(uint256 amount) internal override {}

    function _harvest(address rewardToken, bytes) internal override returns (uint256) {}
}
