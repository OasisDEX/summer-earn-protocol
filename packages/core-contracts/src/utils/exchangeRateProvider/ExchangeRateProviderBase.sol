// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.27;

import "@summerfi/percentage-solidity/contracts/Percentage.sol";
import "@summerfi/percentage-solidity/contracts/PercentageUtils.sol";

abstract contract ExchangeRateProvider {
    using PercentageUtils for uint256;

    Percentage public emaRange;

    event EmaRangeUpdated(Percentage newEmaRange);

    error EmaRangeTooHigh(Percentage emaRange);

    constructor(Percentage _initialEmaRange) {
        _setEmaRange(_initialEmaRange);
    }

    function getExchangeRate() public view virtual returns (uint256);
    function getExchangeRateEma() public view virtual returns (uint256);
    function getLowerBound() public view virtual returns (uint256) {
        return getExchangeRate().subtractPercentage(emaRange);
    }

    function getUpperBound() public view virtual returns (uint256) {
        return getExchangeRate().addPercentage(emaRange);
    }
    function _setEmaRange(Percentage newEmaRange) internal virtual {
        if (newEmaRange > PERCENTAGE_100) {
            revert EmaRangeTooHigh(newEmaRange);
        }
        emaRange = newEmaRange;
        emit EmaRangeUpdated(newEmaRange);
    }

    function _applyEmaRange(
        uint256 price
    ) internal view virtual returns (uint256);
}
