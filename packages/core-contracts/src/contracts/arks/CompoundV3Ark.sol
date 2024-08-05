// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IComet} from "../../interfaces/compound-v3/IComet.sol";
import {IArk} from "../../interfaces/IArk.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ICometRewards} from "../../interfaces/compound-v3/ICometRewards.sol";
import {Test, console} from "forge-std/Test.sol";

contract CompoundV3Ark is Ark {
    using SafeERC20 for IERC20;

    uint256 public constant SECONDS_PER_YEAR = 31536000;
    uint256 public constant WAD_TO_RAY = 1e9;
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
        token.approve(address(comet), amount);
        comet.supply(address(token), amount);
    }

    function _disembark(uint256 amount) internal override {
        comet.withdraw(address(token), amount);
    }

    function _harvest(address rewardToken, bytes) internal override returns (uint256) {
        cometRewards.claim(address(comet), address(this), true);

        uint256 claimedRewardsBalance = IERC20(rewardToken).balanceOf(
            address(this)
        );
        IERC20(rewardToken).safeTransfer(raft, claimedRewardsBalance);

        emit Harvested(claimedRewardsBalance);

        return claimedRewardsBalance;
    }
}
