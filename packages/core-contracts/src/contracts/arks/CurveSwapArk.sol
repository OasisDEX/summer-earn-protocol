// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import {BaseSwapArk, ArkParams} from "./BaseSwapArk.sol";
import {ICurveSwap} from "../../interfaces/curve/ICurveSwap.sol";
import {PendlePTArk, PendlePtArkConstructorParams} from "./PendlePTArk.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
struct CurveSwapArkConstructorParams {
    address curvePool;
    address susde;
}
import {console} from "forge-std/console.sol";

contract CurveSwapPendlePtArk is PendlePTArk {
    // 0x02950460e2b9529d0e00284a5fa2d7bdf3fa4d72

    //     - Only allow to trade when the current EMA value is between 0.99925 and 1.00075 usde/usdc
    // - Only allow the trade if the quoted price of the trade, with impact and fees taken into account, is between 0.99925 and 1.00075 usde/usdc
    // - In order to try and compensate for price impact, it should only buy if it can achieve an effective Fixed Yield of at least 10%
    // - It should not enter markets with less than 20 days remaining

    ICurveSwap public curveSwap;
    IERC4626 public susde;
    uint256 public lowerEma = 0.9995 * 1e18;
     uint256 public upperEma = 1.00099 * 1e18;

    int128 public constant USDE_INDEX = 0;
    int128 public constant USDC_INDEX = 1;

    constructor(
        ArkParams memory _params,
        PendlePtArkConstructorParams memory _pendlePtArkConstructorParams,
        CurveSwapArkConstructorParams memory _curveSwapArkConstructorParams
    ) PendlePTArk(_pendlePtArkConstructorParams, _params) {
        curveSwap = ICurveSwap(_curveSwapArkConstructorParams.curvePool);
        susde = IERC4626(_curveSwapArkConstructorParams.susde);
    }

    function getExchangeRate() public view returns (uint256 price) {
        price = curveSwap.last_price(0);
    }

    function _board(
        uint256 amount,
        bytes calldata data
    ) internal override shouldBuy {
        uint256 usdcAmount = amount;
        uint256 perfectOut = (usdcAmount * getExchangeRate()  ) / 1e6;
        console.log("preview susde amount     : ", susde.previewDeposit(perfectOut));
        console.log("perfectOut               : ", perfectOut);
        uint256 minUsdeOut =( ( usdcAmount * getExchangeRate() * lowerEma  ) / 1e18)/ 1e6;
        IERC20(curveSwap.coins(1)).approve(address(curveSwap), usdcAmount);
        uint256 usdeAmount = curveSwap.exchange(
            USDC_INDEX,
            USDE_INDEX,
            usdcAmount,
            minUsdeOut
        );
        console.log("usdcAmount               : ", usdcAmount);
        console.log("minUsdeOut               : ", minUsdeOut );
        console.log("bought usde              : ", usdeAmount);
        IERC20(curveSwap.coins(0)).approve(address(susde), usdeAmount);
        susde.deposit(usdeAmount, address(this));
        console.log("got    susde             : ", susde.balanceOf(address(this)));
        super._board(susde.balanceOf(address(this)), data);
    }

    function x(uint256 amount, bytes calldata data) public {
        IERC20(curveSwap.coins(1)).transferFrom(msg.sender, address(this), amount);
        _board(amount, data);
    }

    function _disembark(
        uint256 amount,
        bytes calldata data
    ) internal override shouldTrade {
        // super._disembark(amount, data);
        // susde.withdraw(amount, address(this), address(this));
        // uint256 minUsdcOut = amount;
        // curveSwap.exchange(USDE_INDEX, USDC_INDEX, amount, 0);
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
