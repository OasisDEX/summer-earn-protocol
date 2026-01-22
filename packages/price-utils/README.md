# Prices library for Solidity

This library handles prices in base/quote notation where a price represents how much quote asset is
needed to buy one unit of the base asset. This is represented as BASE/QUOTE. For example, a price of
2000 USDC per ETH would be represented as ETH/USDC = 2000.

### Features

The library abstracts the complexisty of handling prices for bases and quotes with different
decimals and provides a simple interface for price manipulation and calculations.

- Custom `Price` type that holds the ratio of base to quote
- Free function `toPrice` to create Price instances
- Custom `Price` functions: `invert()` and `quote(amount)`
- Custom `uint256` functions: `mul(Price)`, `div(Price)`

### Caveats

Understand that the nomenclature of base and quote is the inverse of the mathematical ratio. For
example, if the price is 2000 USDC per ETH, the mathematical ratio is 1 ETH / 2000 USDC = 0.0005,
but the base/quote representation is ETH/USDC = 2000.

In this library, when quoting an amount using a price, we mean converting an amount of the quote
asset to the equivalent amount of the base asset using the price. For example, if we have a price of
2000 USDC per ETH (ETH/USDC = 2000), and we want to quote 4000 USDC, we would get 2 ETH.

This is the same as multiplying the quote amount by the price using `.mul()` on a `uint256` type.

## Usage Examples

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import '../contracts/PriceUtils.sol';

contract PriceExample {
  using PriceUtils for Price;
  using PriceUtils for uint256;

  function quoteAmount() public pure {
    uint256 baseAmount = 1e6; // USDC
    uint256 quoteAmount = 2e18; // ETH

    Price memory priceUSDC_ETH = toPrice(baseAmount, quoteAmount);

    uint256 inputQuoteAmount = 10e18; // 10 ETH

    uint256 outputAmountUSDC = priceUSDC_ETH.quote(inputQuoteAmount); // 5e6 USDC
  }

  function chainPrices() public pure {
    uint256 priceABase = 10000e9; // SUMR
    uint256 priceAQuote = 1e8; // WBTC

    uint256 priceBBase = 1e8; // WBTC
    uint256 priceBQuote = 100000e6; // USDC

    Price memory priceA = toPrice(priceABase, priceAQuote);
    Price memory priceB = toPrice(priceBBase, priceBQuote);

    uint256 inputAmount = 200000e6; // USDC

    uint256 outputAmount = inputAmount.mul(priceB).mul(priceA); // 20000e9 SUMR
  }
}
```
