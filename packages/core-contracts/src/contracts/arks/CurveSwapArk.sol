// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseSwapArk, ArkParams} from "./BaseSwapArk.sol";
import {ICurveSwap} from "../../interfaces/curve/ICurveSwap.sol";
import {PendlePTArk, PendlePtArkConstructorParams} from "./PendlePTArk.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
struct CurveSwapArkConstructorParams {
    address curvePool;
    address susde;
}

contract CurveSwapPendlePtArk is PendlePTArk {
    // 0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72

    //     - Only allow to trade when the current EMA value is between 0.99925 and 1.00075 usde/usdc
    // - Only allow the trade if the quoted price of the trade, with impact and fees taken into account, is between 0.99925 and 1.00075 usde/usdc
    // - In order to try and compensate for price impact, it should only buy if it can achieve an effective Fixed Yield of at least 10%
    // - It should not enter markets with less than 20 days remaining

    ICurveSwap public curveSwap;
    IERC4626 public susde;
    uint256 public lowerEma = 0.99925 * 1e18;
    uint256 public upperEma = 1.00075 * 1e18;
    uint256 public constant USDE_INDEX = 0;
    uint256 public constant USDC_INDEX = 1;

    constructor(
        ArkParams memory _params,
        PendlePtArkConstructorParams memory _pendlePtArkConstructorParams,
        CurveSwapArkConstructorParams memory _curveSwapArkConstructorParams
    ) PendlePTArk(_pendlePtArkConstructorParams, _params) {
        curveSwap = ICurveSwap(_curveSwapArkConstructorParams.curvePool);
    }

    function getExchangeRate() public view returns (uint256 price) {
        price = curveSwap.ema_price(0);
    }

    function _board(uint256 amount, bytes calldata data) internal override shouldBuy {
        uint256 usdcAmount = amount;
        uint256 minUsdeOut = (usdcAmount * getExchangeRate() * 99925) / 100000;
        uint256 usdeAmount = curveSwap.exchange(
            USDC_INDEX,
            USDE_INDEX,
            usdcAmount,
            minUsdeOut
        );
        susde.deposit(usdeAmount, address(this));
        super._board(susde.balanceOf(address(this)), data);
    }
    function _disembark(uint256 amount, bytes calldata data) internal override shouldTrade {
        super._disembark(amount, data);
        susde.withdraw(amount, address(this), address(this));
        uint256 minUsdcOut = amount;
        uint256 minUsde
        curveSwap.exchange(USDE_INDEX, USDC_INDEX, amount, 0);
    }

    modifier shouldBuy() {
        _shouldTrade();
        require(
            marketExpiry > block.timestamp + 20 days,
            "Market has less than 20 days remaining"
        );
        _;
    }

    function _shouldTrade() internal view {
        require(
            onlyWhenBetween(curveSwap.ema_price(0), lowerEma, upperEma),
            "EMA is not between 0.99925 and 1.00075"
        );
    }

    function onlyWhenBetween(
        uint256 number,
        uint256 lower,
        uint256 upper
    ) internal pure returns (bool) {
        return number >= lower && number <= upper;
    }

    modifier shouldTrade() {
        _shouldTrade();
        _;
    }
}
