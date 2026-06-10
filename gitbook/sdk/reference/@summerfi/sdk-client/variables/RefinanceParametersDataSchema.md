# Variable: RefinanceParametersDataSchema

```ts
const RefinanceParametersDataSchema: ZodObject<{
  slippage: ZodType<IPercentage, ZodTypeDef, IPercentage>;
  sourcePosition: ZodType<ILendingPosition, ZodTypeDef, ILendingPosition>;
  targetPool: ZodType<ILendingPool, ZodTypeDef, ILendingPool>;
}, "strip", ZodTypeAny, {
  slippage: IPercentage;
  sourcePosition: ILendingPosition;
  targetPool: ILendingPool;
}, {
  slippage: IPercentage;
  sourcePosition: ILendingPosition;
  targetPool: ILendingPool;
}>;
```

Defined in: [sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/refinance/interfaces/IRefinanceParameters.ts#L31)

Zod schema for the refinance parameters
