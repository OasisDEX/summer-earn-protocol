# Variable: ArmadaProtocolDataSchema

```ts
const ArmadaProtocolDataSchema: ZodObject<{
  chainInfo: ZodType<IChainInfo, ZodTypeDef, IChainInfo>;
  name: ZodLiteral<Armada>;
}, "strip", ZodTypeAny, {
  chainInfo: IChainInfo;
  name: Armada;
}, {
  chainInfo: IChainInfo;
  name: Armada;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaProtocol.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaProtocol.ts#L25)

## Description

Zod schema for IArmadaProtocol
