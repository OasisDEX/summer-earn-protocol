# Function: multiplyTokenAmountByPrice()

```ts
function multiplyTokenAmountByPrice(tokenAmount, price): 
  | Readonly<{
  amount: string;
  token: ITokenStanalone;
}>
  | Readonly<{
  amount: string;
  fiat: FiatCurrency;
}>;
```

Defined in: [sdk/sdk-common/src/common/utils/PriceUtils.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/utils/PriceUtils.ts#L19)

Multiply a token amount by a price

## Parameters

### tokenAmount

[`ITokenAmount`](../interfaces/ITokenAmount.md)

The token amount to multiply

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

The resulting token amount or currency amount depending on the price quote
