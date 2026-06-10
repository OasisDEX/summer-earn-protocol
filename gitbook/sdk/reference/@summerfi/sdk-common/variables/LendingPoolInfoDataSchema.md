# Variable: LendingPoolInfoDataSchema

```ts
const LendingPoolInfoDataSchema: ZodObject<{
  collateral: ZodType<ICollateralInfo, ZodTypeDef, ICollateralInfo>;
  debt: ZodType<IDebtInfo, ZodTypeDef, IDebtInfo>;
  id: ZodType<ILendingPoolId, ZodTypeDef, ILendingPoolId>;
  type: ZodLiteral<Lending>;
}, "strip", ZodTypeAny, {
  collateral: ICollateralInfo;
  debt: IDebtInfo;
  id: ILendingPoolId;
  type: Lending;
}, {
  collateral: ICollateralInfo;
  debt: IDebtInfo;
  id: ILendingPoolId;
  type: Lending;
}>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L42)

## Description

Zod schema for ILendingPoolInfo
