# Variable: TokenAmountDataSchema

```ts
const TokenAmountDataSchema: ZodObject<{
  amount: ZodString;
  token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
}, "strip", ZodTypeAny, {
  amount: string;
  token: ITokenStanalone;
}, {
  amount: string;
  token: ITokenStanalone;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:129](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L129)

## Description

Zod schema for ITokenAmount
