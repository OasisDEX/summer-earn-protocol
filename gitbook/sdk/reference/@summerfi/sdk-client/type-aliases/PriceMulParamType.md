# Type Alias: PriceMulParamType

```ts
type PriceMulParamType = 
  | string
  | number
  | IPrice
  | ITokenAmount
  | IFiatCurrencyAmount
  | IPercentage;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrice.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrice.ts#L19)

Return Type narrowing for multiply and divide methods, so the return type can be properly inferred

This helps callers to know what to expect from the result of the operation
