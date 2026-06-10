# Variable: PoolDataSchema

```ts
const PoolDataSchema: ZodObject<{
  id: ZodType<IPoolId, ZodTypeDef, IPoolId>;
  type: ZodNativeEnum<typeof PoolType>;
}, "strip", ZodTypeAny, {
  id: IPoolId;
  type: PoolType;
}, {
  id: IPoolId;
  type: PoolType;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L30)

## Description

Zod schema for IPool
