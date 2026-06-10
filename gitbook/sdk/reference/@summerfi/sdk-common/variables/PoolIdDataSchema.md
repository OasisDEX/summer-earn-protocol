# Variable: PoolIdDataSchema

```ts
const PoolIdDataSchema: ZodObject<{
  protocol: ZodType<IProtocol, ZodTypeDef, IProtocol>;
  type: ZodNativeEnum<typeof PoolType>;
}, "strip", ZodTypeAny, {
  protocol: IProtocol;
  type: PoolType;
}, {
  protocol: IProtocol;
  type: PoolType;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L29)

## Description

Zod schema for IPoolId
