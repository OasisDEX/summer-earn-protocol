// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

/**
 * @title ExchangeRateProviderBase
 * @dev Abstract base contract for exchange rate providers with EMA range adjustment.
 *
 * This contract serves as a foundation for implementing exchange rate providers
 * with built-in price smoothing using an Exponential Moving Average (EMA) range.
 * It defines a common interface for getting exchange rates and their EMAs,
 * as well as calculating upper and lower bounds based on the EMA range.
 *
 * Key features:
 * - Maintains an adjustable EMA range for price smoothing
 * - Provides abstract functions for current rates and EMAs
 * - Implements bound calculations based on the EMA range
 * - Includes a mechanism to set and update the EMA range
 *
 * The abstraction allows for various implementations while ensuring
 * consistency across different providers. This design facilitates
 * easy swapping of providers and promotes code reusability.
 */
abstract contract ExchangeRateProvider {
    using PercentageUtils for uint256;

    /// @notice The EMA (Exponential Moving Average) range for price smoothing
    Percentage public lowerPercentageRange;
    Percentage public upperPercentageRange;

    /// @notice The base price for the exchange rate
    uint256 public basePrice;

    /**
     * @notice Emitted when the EMA range is updated
     * @param lowerPercentageRange The new lower EMA range value
     * @param upperPercentageRange The new upper EMA range value
     */
    event EmaRangeUpdated(
        Percentage lowerPercentageRange,
        Percentage upperPercentageRange
    );

    /**
     * @notice Emitted when the base price is updated
     * @param basePrice The new base price value
     */
    event BasePriceUpdated(uint256 basePrice);

    /**
     * @notice Error thrown when the provided EMA range is too high
     * @param emaRange The invalid EMA range value
     */
    error EmaRangeTooHigh(Percentage emaRange);

    /// @notice Error thrown when the provided base price is zero
    /// @param basePrice The invalid base price value
    error InvalidBasePrice(uint256 basePrice);

    /**
     * @dev Constructor to initialize the ExchangeRateProvider
     * @param _lowerPercentageRange Lower EMA range for price smoothing
     * @param _upperPercentageRange Upper EMA range for price smoothing
     */
    constructor(
        Percentage _lowerPercentageRange,
        Percentage _upperPercentageRange,
        uint256 _basePrice
    ) {
        _setEmaRange(_lowerPercentageRange, _upperPercentageRange);
        basePrice = _basePrice;
        emit BasePriceUpdated(_basePrice);
    }

    /**
     * @notice Get the current exchange rate
     * @return The current exchange rate
     */
    function getExchangeRate() public view virtual returns (uint256);

    /**
     * @notice Get the EMA (Exponential Moving Average) of the exchange rate
     * @return The EMA of the exchange rate
     */
    function getExchangeRateEma() public view virtual returns (uint256);

    /**
     * @notice Get the lower bound of the exchange rate based on the EMA range
     * @return The lower bound of the exchange rate
     */
    function getLowerBound() public view virtual returns (uint256) {
        return basePrice.subtractPercentage(lowerPercentageRange);
    }

    /**
     * @notice Get the upper bound of the exchange rate based on the EMA range
     * @return The upper bound of the exchange rate
     */
    function getUpperBound() public view virtual returns (uint256) {
        return basePrice.addPercentage(upperPercentageRange);
    }

    /**
     * @notice Set a new EMA range
     * @dev Internal function to update the EMA range, ensuring it's not greater than 100%
     * @param _lowerPercentageRange The new lower EMA range to set
     * @param _upperPercentageRange The new upper EMA range to set
     */
    function _setEmaRange(
        Percentage _lowerPercentageRange,
        Percentage _upperPercentageRange
    ) internal virtual {
        if (_lowerPercentageRange > PERCENTAGE_100) {
            revert EmaRangeTooHigh(_lowerPercentageRange);
        }
        if (_upperPercentageRange > PERCENTAGE_100) {
            revert EmaRangeTooHigh(_upperPercentageRange);
        }
        lowerPercentageRange = _lowerPercentageRange;
        upperPercentageRange = _upperPercentageRange;
        emit EmaRangeUpdated(_lowerPercentageRange, _upperPercentageRange);
    }

    function _setBasePrice(uint256 _basePrice) internal virtual {
        if (_basePrice == 0) {
            revert InvalidBasePrice(_basePrice);
        }
        basePrice = _basePrice;
        emit BasePriceUpdated(_basePrice);
    }

    /**
     * @notice Apply the EMA range to the given price
     * @dev Abstract function to be implemented by derived contracts
     * @param price The input price to adjust
     * @return The price after applying the EMA range
     */
    function _applyRange(uint256 price) internal view virtual returns (uint256);
}
