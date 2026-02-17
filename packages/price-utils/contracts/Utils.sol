// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.28;

import {UD60x18, ud, intoUint256} from "@prb/math/src/UD60x18.sol";
import {Price} from "./Types.sol";
import {toPrice} from "./Constructor.sol";

/**
    @title PriceUtils

    @author Roberto Cano <robercano>
    
    @notice Utility library to manage prices in Solidity. The prices use the convention of base and quote assets, 
    where the price is expressed as how much quote asset is needed to buy one unit of the base asset.

    In this sense a typical listed price of ETH/USD = 2000 means that 2000 USD (quote) are needed to buy 1 ETH (base).

    This is contrary to the mathematical convention of price = base/quote, but it is more aligned with how prices are
    typically represented in financial markets.

    An example of this is a price of ETH/USD = 2000, which means that the price is 2000 USD per ETH, which would be represented
    mathematically as 1/2000 = 0.0005 ETH per USD.
 */
library PriceUtils {
    using PriceUtils for Price;

    /**
      @notice Inverts a given Price type, swapping base and quote amounts and decimals

      @param price The Price type to invert

      @return The inverted Price type

      @dev Used to convert from base/quote to quote/base representation
    */
    function invert(Price memory price) internal pure returns (Price memory) {
        return
            toPrice(
                intoUint256(price.quoteAmount),
                intoUint256(price.baseAmount)
            );
    }

    /**
      @notice Given an amount of quote asset it calculates how much amount of the base 
      asset will be received at the given price rate

      @param price The price rate of base/quote
      @param amount The amount of quote asset to convert, as a uint256

      @return The amount of base asset that will be received
    */
    function quote(
        Price memory price,
        uint256 amount
    ) internal pure returns (uint256) {
        return
            intoUint256(
                ud(amount).mul(price.baseAmount).div(price.quoteAmount)
            );
    }

    /**
      @notice Multiplies an amount by a price, effectively quoting the amount from quote asset to base asset

      @param amount The amount of quote asset to convert, as a uint256
      @param price The price rate of base/quote

      @return The amount of base asset that will be received

      @dev This is a convenience function that calls .quote() with the parameters reversed so that it 
           can be chained:

              uint256 baseAmount = priceA.quote(amountA).mul(priceB);
     */
    function mul(
        uint256 amount,
        Price memory price
    ) internal pure returns (uint256) {
        return quote(price, amount);
    }

    /**
      @notice Divides an amount by a price, effectively quoting the amount from base asset to
              quote asset

      @param amount The amount of base asset to convert, as a uint256
      @param price The price rate of base/quote
    
      @return The amount of quote asset that will be received
      
      @dev This is a convenience function that calls .invert().quote() with the parameters reversed
           so that it can be chained:

              uint256 quoteAmount = priceA.invert().quote(amountA).div(priceB);
     */
    function div(
        uint256 amount,
        Price memory price
    ) internal pure returns (uint256) {
        return price.invert().quote(amount);
    }
}
