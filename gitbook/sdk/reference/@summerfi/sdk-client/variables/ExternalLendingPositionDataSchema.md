# Variable: ExternalLendingPositionDataSchema

```ts
const ExternalLendingPositionDataSchema: ZodObject<{
  collateralAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  debtAmount: ZodType<ITokenAmount, ZodTypeDef, ITokenAmount>;
  id: ZodType<IExternalLendingPositionId, ZodTypeDef, IExternalLendingPositionId>;
  pool: ZodType<ILendingPool, ZodTypeDef, ILendingPool>;
  subtype: ZodNativeEnum<typeof LendingPositionType>;
  type: ZodLiteral<Lending>;
}, "strip", ZodTypeAny, {
  collateralAmount: ITokenAmount;
  debtAmount: ITokenAmount;
  id: IExternalLendingPositionId;
  pool: ILendingPool;
  subtype: LendingPositionType;
  type: Lending;
}, {
  collateralAmount: ITokenAmount;
  debtAmount: ITokenAmount;
  id: IExternalLendingPositionId;
  pool: ILendingPool;
  subtype: LendingPositionType;
  type: Lending;
}>;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts#L28)

## Description

Zod schema for IExternalLendingPosition
