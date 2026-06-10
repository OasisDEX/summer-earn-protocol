# Variable: LendingPositionDataSchema

```ts
const LendingPositionDataSchema: ZodObject<{
  collateralAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  debtAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  id: ZodType<ILendingPositionId, ZodTypeDef, ILendingPositionId>;
  pool: ZodType<ILendingPool, ZodTypeDef, ILendingPool>;
  subtype: ZodNativeEnum<typeof LendingPositionType>;
  type: ZodLiteral<Lending>;
}, "strip", ZodTypeAny, {
  collateralAmount: ITokenAmount;
  debtAmount: ITokenAmount;
  id: ILendingPositionId;
  pool: ILendingPool;
  subtype: LendingPositionType;
  type: Lending;
}, {
  collateralAmount: ITokenAmount;
  debtAmount: ITokenAmount;
  id: ILendingPositionId;
  pool: ILendingPool;
  subtype: LendingPositionType;
  type: Lending;
}>;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L39)

## Description

Zod schema for ILendingPosition
