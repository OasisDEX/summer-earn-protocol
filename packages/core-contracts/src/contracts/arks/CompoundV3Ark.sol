// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IComet} from "../../interfaces/compound-v3/IComet.sol";

contract CompoundV3Ark is Ark {
    using SafeERC20 for IERC20;

    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public constant WAD_TO_RAY = 1e9;
    IComet public comet;

    constructor(address _comet, ArkParams memory _params) Ark(_params) {
        comet = IComet(_comet);
    }

    function rate() public view override returns (uint256 supplyRate) {
        uint256 utilization = comet.getUtilization();
        uint256 supplyRatePerSecond = comet.getSupplyRate(utilization);
        supplyRate = supplyRatePerSecond * SECONDS_PER_YEAR * WAD_TO_RAY;
    }

    function totalAssets()
        public
        view
        override
        returns (uint256 suppliedAssets)
    {
        suppliedAssets = comet.balanceOf(address(this));
    }

    function _board(uint256 amount) internal override {
        token.approve(address(comet), amount);
        comet.supply(address(token), amount);
    }

    function _disembark(uint256 amount) internal override {
        comet.withdraw(address(token), amount);
    }
}
