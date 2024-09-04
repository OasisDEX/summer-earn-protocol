// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseSwapArk, ArkParams} from "./BaseSwapArk.sol";

contract SimpleSwapArk is BaseSwapArk {
    uint32 public twapInterval;

    constructor(
        ArkParams memory _params,
        address _arkToken
    ) BaseSwapArk(_params, _arkToken) {}

    function getExchangeRate() public pure override returns (uint256) {
        return 1e18;
    }

    function _harvest(
        address rewardToken,
        bytes calldata
    ) internal override returns (uint256) {}
}
