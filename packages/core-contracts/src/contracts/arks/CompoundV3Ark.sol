// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IComet} from "../../interfaces/compound-v3/IComet.sol";
import {ICometRewards} from "../../interfaces/compound-v3/ICometRewards.sol";

contract CompoundV3Ark is Ark {
    using SafeERC20 for IERC20;

    IComet public comet;
    ICometRewards public cometRewards;

    constructor(
        address _comet,
        address _cometRewards,
        ArkParams memory _params
    ) Ark(_params) {
        comet = IComet(_comet);
        cometRewards = ICometRewards(_cometRewards);
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
        config.token.approve(address(comet), amount);
        comet.supply(address(config.token), amount);
    }

    function _disembark(uint256 amount) internal override {
        comet.withdraw(address(config.token), amount);
    }

    function _harvest(
        address rewardToken,
        bytes calldata
    ) internal override returns (uint256 claimedRewardsBalance) {
        cometRewards.claim(address(comet), address(this), true);

        claimedRewardsBalance = IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).safeTransfer(config.raft, claimedRewardsBalance);

        emit Harvested(claimedRewardsBalance);
    }
}
