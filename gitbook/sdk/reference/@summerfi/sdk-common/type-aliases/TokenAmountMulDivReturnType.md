# Type Alias: TokenAmountMulDivReturnType\<T\>

```ts
type TokenAmountMulDivReturnType<T> = T extends IPrice ? 
  | ITokenAmount
  | IFiatCurrencyAmount : T extends IPercentage | string | number ? ITokenAmount : never;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L20)

## Type Parameters

### T

`T`
