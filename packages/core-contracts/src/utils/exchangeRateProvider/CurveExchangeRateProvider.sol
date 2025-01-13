// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "../../../src/interfaces/curve/ICurveSwap.sol";
import "./ExchangeRateProviderBase.sol";

/**
 * @title CurveExchangeRateProvider
 * @dev Exchange rate provider specifically designed for Curve swap pools.
 *
 * This contract extends ExchangeRateProviderBase to work with Curve's liquidity pools,
 * providing exchange rate functionality tailored for Curve's unique pricing mechanism.
 * It interacts directly with a Curve swap pool to fetch and process price data.
 *
 * Key features:
 * - Fetches and processes price data from Curve swap pools
 * - Applies EMA range smoothing to Curve prices
 * - Handles potential rate inversion based on token order in the pool
 * - Maintains consistency with the base ExchangeRateProvider interface
 *
 * By leveraging Curve's popularity and efficiency in stablecoin swaps,
 * this provider offers reliable and accurate exchange rates. The design
 * allows it to work with any Curve pool, regardless of token order,
 * enhancing its flexibility and reusability across different setups.
 */
contract CurveExchangeRateProvider is ExchangeRateProvider {
    using PercentageUtils for uint256;

    /// @notice The Curve swap pool interface
    ICurveSwap public immutable curveSwap;

    /// @notice The base token address for the exchange rate
    address public immutable baseToken;

    /// @notice Error thrown when an invalid base token is provided
    /// @param baseToken The invalid base token address
    error InvalidBaseToken(address baseToken);

    /// @notice Error thrown when an invalid curve swap is provided
    /// @param curveSwap The invalid curve swap address
    error InvalidCurveSwap(address curveSwap);

    constructor(
        address _curveSwap,
        address _baseToken,
        Percentage _lowerPercentageRange,
        Percentage _upperPercentageRange,
        uint256 _basePrice
    )
        ExchangeRateProvider(
            _lowerPercentageRange,
            _upperPercentageRange,
            _basePrice
        )
    {
        if (_curveSwap == address(0)) {
            revert InvalidCurveSwap(_curveSwap);
        }
        curveSwap = ICurveSwap(_curveSwap);
        if (_baseToken == address(0)) {
            revert InvalidBaseToken(_baseToken);
        }
        if (
            _baseToken != curveSwap.coins(0) && _baseToken != curveSwap.coins(1)
        ) {
            revert InvalidBaseToken(_baseToken);
        }
        baseToken = _baseToken;
    }

    /**
     * @notice Get the current exchange rate without applying EMA range
     * @dev Retrieves the last price from the Curve pool and inverts if necessary
     * @return price The current exchange rate
     */
    function getExchangeRate() public view override returns (uint256 price) {
        price = curveSwap.last_price(0);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }

    /**
     * @notice Get the EMA (Exponential Moving Average) of the exchange rate without applying EMA range
     * @dev Retrieves the EMA price from the Curve pool and inverts if necessary
     * @return price The EMA of the exchange rate
     */
    function getExchangeRateEma() public view override returns (uint256 price) {
        price = curveSwap.price_oracle(0);
        if (_shouldInvertExchangeRate()) {
            price = 1e36 / price;
        }
    }

    /**
     * @notice Get the current exchange rate with EMA range applied
     * @dev Retrieves the last price from the Curve pool, inverts if necessary, and applies EMA range
     * @return price The current exchange rate with EMA range applied
     */
    function getSafeExchangeRate() public view returns (uint256 price) {
        price = getExchangeRate();
        price = _applyRange(price);
    }

    /**
     * @notice Get the EMA of the exchange rate with EMA range applied
     * @dev Retrieves the EMA price from the Curve pool, inverts if necessary, and applies EMA range
     * @return price The EMA of the exchange rate with EMA range applied
     */
    function getSafeExchangeRateEma() public view returns (uint256 price) {
        price = getExchangeRateEma();
        price = _applyRange(price);
    }

    /**
     * @notice Apply range to the given price
     * @dev Ensures the price stays within the defined range
     * @param price The input price to adjust
     * @return The price after applying the range
     */
    function _applyRange(
        uint256 price
    ) internal view override returns (uint256) {
        uint256 lowerBound = getLowerBound();
        uint256 upperBound = getUpperBound();
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
