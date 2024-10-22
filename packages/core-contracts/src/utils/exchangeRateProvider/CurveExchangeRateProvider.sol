// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "./ExchangeRateProviderBase.sol";
import "../../../src/interfaces/curve/ICurveSwap.sol";
import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

contract CurveExchangeRateProvider is ExchangeRateProvider {
    using PercentageUtils for uint256;

    /// @notice The Curve swap pool interface
    ICurveSwap public curveSwap;

    /// @notice The base token address for the exchange rate
    address public baseToken;

    /// @notice Error thrown when an invalid base token is provided
    /// @param baseToken The invalid base token address
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

    /**
     * @notice Get the current exchange rate
     * @dev Retrieves the last price from the Curve pool, applies EMA range, and inverts if necessary
     * @return price The current exchange rate
     */
    function getExchangeRate() public view override returns (uint256 price) {
        price = curveSwap.last_price(0);
        price = _applyEmaRange(price);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }

    /**
     * @notice Get the EMA (Exponential Moving Average) of the exchange rate
     * @dev Retrieves the EMA price from the Curve pool, applies EMA range, and inverts if necessary
     * @return price The EMA of the exchange rate
     */
    function getExchangeRateEma() public view override returns (uint256 price) {
        price = curveSwap.ema_price(0);
        price = _applyEmaRange(price);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }

    /**
     * @notice Apply the EMA range to the given price
     * @dev Ensures the price stays within the defined EMA range
     * @param price The input price to adjust
     * @return The price after applying the EMA range
     */
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

    /**
     * @notice Determine if the exchange rate should be inverted
     * @dev Checks if the second token in the Curve pool is not the base token
     * @return True if the exchange rate should be inverted, false otherwise
     */
    function _shouldInvertExchangeRate() internal view returns (bool) {
        return curveSwap.coins(1) != baseToken;
    }
}
