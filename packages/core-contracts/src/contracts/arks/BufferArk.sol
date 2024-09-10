// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";

contract BufferArk is Ark {
    constructor(ArkParams memory _params) Ark(_params) {}

    function totalAssets() public view override returns (uint256) {
        return config.token.balanceOf(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {}

    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override {}

    function _harvest(
        address rewardToken,
        bytes calldata
    ) internal override returns (uint256) {}

    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
