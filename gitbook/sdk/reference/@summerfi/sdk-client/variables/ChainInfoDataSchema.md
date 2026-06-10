# Variable: ChainInfoDataSchema

```ts
const ChainInfoDataSchema: ZodObject<{
  chainId: ZodUnion<[ZodUnion<[ZodLiteral<1 | 146 | 999 | 8453 | 42161>, ZodLiteral<1 | 146 | 999 | 8453 | 42161>, ...ZodLiteral<1 | 146 | 999 | 8453 | 42161>[]]>, ZodUnion<[ZodLiteral<1 | 10 | 146 | 8453 | 42161>, ZodLiteral<1 | 10 | 146 | 8453 | 42161>, ...ZodLiteral<1 | 10 | 146 | 8453 | 42161>[]]>]>;
  name: ZodString;
}, "strip", ZodTypeAny, {
  chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
  name: string;
}, {
  chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
  name: string;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IChainInfo.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IChainInfo.ts#L36)

## Description

Zod schema for IChainInfo
