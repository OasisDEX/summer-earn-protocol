# Type Alias: PriceMulReturnType\<T\>

```ts
type PriceMulReturnType<T> = T extends ITokenAmount ? 
  | ITokenAmount
  | IFiatCurrencyAmount : T extends IFiatCurrencyAmount ? 
  | IFiatCurrencyAmount
  | ITokenAmount : IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L26)

## Type Parameters

### T

`T`
