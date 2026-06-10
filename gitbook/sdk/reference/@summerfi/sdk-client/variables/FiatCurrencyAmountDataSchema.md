# Variable: FiatCurrencyAmountDataSchema

```ts
const FiatCurrencyAmountDataSchema: ZodObject<{
  amount: ZodString;
  fiat: ZodNativeEnum<typeof FiatCurrency>;
}, "strip", ZodTypeAny, {
  amount: string;
  fiat: FiatCurrency;
}, {
  amount: string;
  fiat: FiatCurrency;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IFiatCurrencyAmount.ts:84](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IFiatCurrencyAmount.ts#L84)

## Description

Zod schema for IFiatCurrencyAmount
