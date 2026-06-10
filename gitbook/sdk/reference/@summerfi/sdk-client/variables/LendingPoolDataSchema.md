# Variable: LendingPoolDataSchema

```ts
const LendingPoolDataSchema: ZodObject<{
  collateralToken: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
  debtToken: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
  id: ZodType<ILendingPoolId, ZodTypeDef, ILendingPoolId>;
  type: ZodLiteral<Lending>;
}, "strip", ZodTypeAny, {
  collateralToken: ITokenStanalone;
  debtToken: ITokenStanalone;
  id: ILendingPoolId;
  type: Lending;
}, {
  collateralToken: ITokenStanalone;
  debtToken: ITokenStanalone;
  id: ILendingPoolId;
  type: Lending;
}>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L39)

## Description

Zod schema for ILendingPool
