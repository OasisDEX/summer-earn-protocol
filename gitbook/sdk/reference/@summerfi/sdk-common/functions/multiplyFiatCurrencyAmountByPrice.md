# Function: multiplyFiatCurrencyAmountByPrice()

```ts
function multiplyFiatCurrencyAmountByPrice(fiatCurrencyAmount, price): 
  | Readonly<{
  amount: string;
  token: ITokenStanalone;
}>
  | Readonly<{
  amount: string;
  fiat: FiatCurrency;
}>;
```

Defined in: [sdk/sdk-common/src/common/utils/PriceUtils.ts:45](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/utils/PriceUtils.ts#L45)

Multiply a fiat currency amount by a price

## Parameters

### fiatCurrencyAmount

[`IFiatCurrencyAmount`](../interfaces/IFiatCurrencyAmount.md)

The fiat currency amount to multiply

### price

[`IPrice`](../interfaces/IPrice.md)

The price to multiply by

## Returns

  \| `Readonly`\<\{
  `amount`: `string`;
  `token`: [`ITokenStanalone`](../interfaces/ITokenStanalone.md);
\}\>
  \| `Readonly`\<\{
  `amount`: `string`;
  `fiat`: [`FiatCurrency`](../enumerations/FiatCurrency.md);
\}\>

The resulting fiat currency amount or token amount depending on the price quote
