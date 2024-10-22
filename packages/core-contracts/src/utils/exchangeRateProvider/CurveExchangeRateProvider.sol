// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "./ExchangeRateProviderBase.sol";
import "../../../src/interfaces/curve/ICurveSwap.sol";
import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract CurveExchangeRateProvider is ExchangeRateProvider {
    using PercentageUtils for uint256;

    ICurveSwap public curveSwap;
    address public baseToken;

    error InvalidBaseToken(address baseToken);

    constructor(
        address _curveSwap,
        address _baseToken,
        Percentage _initialEmaRange
    ) ExchangeRateProvider(_initialEmaRange) {
        curveSwap = ICurveSwap(_curveSwap);
        if (_baseToken == address(0)) {
            revert InvalidBaseToken(_baseToken);
        }
        baseToken = _baseToken;
    }

    function getExchangeRate() public view override returns (uint256 price) {
        price = curveSwap.last_price(0);
        price = _applyEmaRange(price);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }

    function getExchangeRateEma() public view override returns (uint256 price) {
        price = curveSwap.ema_price(0);
        price = _applyEmaRange(price);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }
    // function getLowerBound() public view override returns (uint256) {
    //     uint256 rate = getExchangeRate();
    //     return rate.subtractPercentage(emaRange);
    // }

    // function getUpperBound() public view override returns (uint256) {
    //     uint256 rate = getExchangeRate();
    //     return rate.addPercentage(emaRange);
    // }

    function _applyEmaRange(
        uint256 price
    ) internal view override returns (uint256) {
        uint256 lowerBound = price.subtractPercentage(emaRange);
        uint256 upperBound = price.addPercentage(emaRange);
        if (price < lowerBound) {
            return lowerBound;
        } else if (price > upperBound) {
            return upperBound;
        }
        return price;
    }

    function _shouldInvertExchangeRate() internal view returns (bool) {
        return curveSwap.coins(1) != baseToken;
    }
}
