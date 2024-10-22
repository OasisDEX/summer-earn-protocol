// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

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
    Percentage public emaRange;

    /**
     * @notice Emitted when the EMA range is updated
     * @param newEmaRange The new EMA range value
     */
    event EmaRangeUpdated(Percentage newEmaRange);

    /**
     * @notice Error thrown when the provided EMA range is too high
     * @param emaRange The invalid EMA range value
     */
    error EmaRangeTooHigh(Percentage emaRange);

    /**
     * @dev Constructor to initialize the ExchangeRateProvider
     * @param _initialEmaRange Initial EMA range for price smoothing
     */
    constructor(Percentage _initialEmaRange) {
        _setEmaRange(_initialEmaRange);
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
        return getExchangeRate().subtractPercentage(emaRange);
    }

    /**
     * @notice Get the upper bound of the exchange rate based on the EMA range
     * @return The upper bound of the exchange rate
     */
    function getUpperBound() public view virtual returns (uint256) {
        return getExchangeRate().addPercentage(emaRange);
    }

    /**
     * @notice Set a new EMA range
     * @dev Internal function to update the EMA range, ensuring it's not greater than 100%
     * @param newEmaRange The new EMA range to set
     */
    function _setEmaRange(Percentage newEmaRange) internal virtual {
        if (newEmaRange > PERCENTAGE_100) {
            revert EmaRangeTooHigh(newEmaRange);
        }
        emaRange = newEmaRange;
        emit EmaRangeUpdated(newEmaRange);
    }

    /**
     * @notice Apply the EMA range to the given price
     * @dev Abstract function to be implemented by derived contracts
     * @param price The input price to adjust
     * @return The price after applying the EMA range
     */
    function _applyEmaRange(
        uint256 price
    ) internal view virtual returns (uint256);
}
