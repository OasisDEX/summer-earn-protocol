# Variable: ArmadaPositionIdDataSchema

```ts
const ArmadaPositionIdDataSchema: ZodObject<{
  id: ZodString;
  type: ZodLiteral<Armada>;
  user: ZodType<IUser, ZodTypeDef, IUser>;
}, "strip", ZodTypeAny, {
  id: string;
  type: Armada;
  user: IUser;
}, {
  id: string;
  type: Armada;
  user: IUser;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPositionId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPositionId.ts#L28)

## Description

Zod schema for IArmadaPositionId
