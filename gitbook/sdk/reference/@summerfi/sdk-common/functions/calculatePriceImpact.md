# Function: calculatePriceImpact()

```ts
function calculatePriceImpact(spotPrice, quotePrice): IPercentage | null;
```

Defined in: [sdk/sdk-common/src/swap/calculatePriceImpact.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/calculatePriceImpact.ts#L12)

## Parameters

### spotPrice

[`IPrice`](../interfaces/IPrice.md)

This price represents a blend of spot prices from various exchanges.

### quotePrice

[`IPrice`](../interfaces/IPrice.md)

The offer price is price quoted to us by a liquidity provider and takes
     into account price impact - where price impact is a measure of how much our trade
     affects the price. It is determined by the breadth and depth of liquidity.

## Returns

[`IPercentage`](../interfaces/IPercentage.md) \| `null`
