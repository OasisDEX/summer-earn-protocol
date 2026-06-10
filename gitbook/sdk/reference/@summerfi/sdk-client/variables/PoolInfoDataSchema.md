# Variable: PoolInfoDataSchema

```ts
const PoolInfoDataSchema: ZodObject<{
  id: ZodObject<{
     protocol: ZodType<IProtocol, ZodTypeDef, IProtocol>;
     type: ZodNativeEnum<typeof PoolType>;
   }, "strip", ZodTypeAny, {
     protocol: IProtocol;
     type: PoolType;
   }, {
     protocol: IProtocol;
     type: PoolType;
  }>;
  type: ZodNativeEnum<typeof PoolType>;
}, "strip", ZodTypeAny, {
  id: {
     protocol: IProtocol;
     type: PoolType;
  };
  type: PoolType;
}, {
  id: {
     protocol: IProtocol;
     type: PoolType;
  };
  type: PoolType;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L28)

## Description

Zod schema for IPoolInfo
