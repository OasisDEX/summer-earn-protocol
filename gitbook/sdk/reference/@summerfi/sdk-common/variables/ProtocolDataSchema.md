# Variable: ProtocolDataSchema

```ts
const ProtocolDataSchema: ZodObject<{
  chainInfo: ZodType<IChainInfo, ZodTypeDef, IChainInfo>;
  name: ZodNativeEnum<typeof ProtocolName>;
}, "strip", ZodTypeAny, {
  chainInfo: IChainInfo;
  name: ProtocolName;
}, {
  chainInfo: IChainInfo;
  name: ProtocolName;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L37)

## Description

Zod schema for IProtocol
