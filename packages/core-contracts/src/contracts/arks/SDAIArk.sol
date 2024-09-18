// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MathUtils} from "@summerfi/math-utils/contracts/MathUtils.sol";
import {IPot} from "../../interfaces/maker/IPot.sol";

contract SDAIArk is Ark {
    using SafeERC20 for IERC20;

    IERC4626 public immutable sDAI;
    IPot public immutable pot;

    constructor(
        address _sDAI,
        address _pot,
        ArkParams memory _params
    ) Ark(_params) {
        sDAI = IERC4626(_sDAI);
        pot = IPot(_pot);

        config.token.approve(_sDAI, type(uint256).max);
    }

    function rate() public view override returns (uint256) {
        uint256 dsrRate = pot.dsr();
        // Convert DSR (per second rate) to APY
        return
            MathUtils.rpow(dsrRate, Constants.SECONDS_PER_YEAR, Constants.RAY) -
            Constants.RAY;
    }

    function totalAssets() public view override returns (uint256) {
        return sDAI.maxWithdraw(address(this));
    }

    function _board(uint256 amount, bytes calldata) internal override {
        sDAI.deposit(amount, address(this));
    }

    function _disembark(uint256 amount, bytes calldata) internal override {
        sDAI.withdraw(amount, address(this), address(this));
    }

    function _harvest(
        bytes calldata
    )
        internal
        pure
        override
        returns (address[] memory rewardTokens, uint256[] memory rewardAmounts)
    {
        rewardTokens = new address[](1);
        rewardAmounts = new uint256[](1);
        rewardTokens[0] = address(0);
        rewardAmounts[0] = 0;
    }

    function _validateBoardData(bytes calldata data) internal override {}
    function _validateDisembarkData(bytes calldata data) internal override {}
}
