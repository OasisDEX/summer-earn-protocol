// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import "../Ark.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IPot} from "../../interfaces/maker/IPot.sol";
import {MathUtils} from "@summerfi/math-utils/contracts/MathUtils.sol";

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

        // Approve sDAI to spend DAI
        config.token.approve(_sDAI, type(uint256).max);
    }

    function rate() public view override returns (uint256) {
        uint256 dsrRate = pot.dsr();
        // Convert DSR (per second rate) to APY
        return MathUtils.rpow(dsrRate, SECONDS_PER_YEAR, RAY) - RAY;
    }

    function totalAssets() public view override returns (uint256) {
        return sDAI.maxWithdraw(address(this));
    }

    function _board(uint256 amount) internal override {
        sDAI.deposit(amount, address(this));
    }

    function _disembark(uint256 amount) internal override {
        sDAI.withdraw(amount, address(this), address(this));
    }

    function _harvest(
        address,
        bytes calldata
    ) internal override returns (uint256) {
        // SDAI automatically accrues interest, so no manual harvesting is needed
        return 0;
    }
}
