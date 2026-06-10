# Variable: PositionIdDataSchema

```ts
const PositionIdDataSchema: ZodObject<{
  id: ZodString;
  type: ZodNativeEnum<typeof PositionType>;
}, "strip", ZodTypeAny, {
  id: string;
  type: PositionType;
}, {
  id: string;
  type: PositionType;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPositionId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPositionId.ts#L25)

## Description

Zod schema for IPositionId
