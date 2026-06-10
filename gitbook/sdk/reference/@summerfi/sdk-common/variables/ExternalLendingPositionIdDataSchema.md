# Variable: ExternalLendingPositionIdDataSchema

```ts
const ExternalLendingPositionIdDataSchema: ZodObject<{
  address: ZodType<IAddress, ZodTypeDef, IAddress>;
  externalType: ZodNativeEnum<typeof ExternalLendingPositionType>;
  id: ZodString;
  protocolId: ZodType<ILendingPositionId, ZodTypeDef, ILendingPositionId>;
  type: ZodLiteral<Lending>;
}, "strip", ZodTypeAny, {
  address: IAddress;
  externalType: ExternalLendingPositionType;
  id: string;
  protocolId: ILendingPositionId;
  type: Lending;
}, {
  address: IAddress;
  externalType: ExternalLendingPositionType;
  id: string;
  protocolId: ILendingPositionId;
  type: Lending;
}>;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPositionId.ts#L38)

## Description

Zod schema for IExternalPositionId
