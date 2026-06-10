# Variable: ArmadaVaultIdDataSchema

```ts
const ArmadaVaultIdDataSchema: ZodObject<{
  chainInfo: ZodType<IChainInfo, ZodTypeDef, IChainInfo>;
  fleetAddress: ZodType<IAddress, ZodTypeDef, IAddress>;
  protocol: ZodType<IArmadaProtocol, ZodTypeDef, IArmadaProtocol>;
  type: ZodLiteral<Armada>;
}, "strip", ZodTypeAny, {
  chainInfo: IChainInfo;
  fleetAddress: IAddress;
  protocol: IArmadaProtocol;
  type: Armada;
}, {
  chainInfo: IChainInfo;
  fleetAddress: IAddress;
  protocol: IArmadaProtocol;
  type: Armada;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L33)

## Description

Zod schema for IArmadaVaultId
