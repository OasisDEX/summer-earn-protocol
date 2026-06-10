# Variable: TokenDataSchema

```ts
const TokenDataSchema: ZodObject<{
  address: ZodObject<{
     type: ZodNativeEnum<typeof AddressType>;
     value: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
   }, "strip", ZodTypeAny, {
     type: AddressType;
     value: `0x${string}`;
   }, {
     type: AddressType;
     value: `0x${string}`;
  }>;
  chainInfo: ZodObject<{
     chainId: ZodUnion<[ZodUnion<[ZodLiteral<1 | 146 | 999 | 8453 | 42161>, ZodLiteral<1 | 146 | 999 | 8453 | 42161>, ...ZodLiteral<1 | 146 | 999 | 8453 | 42161>[]]>, ZodUnion<[ZodLiteral<1 | 10 | 146 | 8453 | 42161>, ZodLiteral<1 | 10 | 146 | 8453 | 42161>, ...ZodLiteral<1 | 10 | 146 | 8453 | 42161>[]]>]>;
     name: ZodString;
   }, "strip", ZodTypeAny, {
     chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
     name: string;
   }, {
     chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
     name: string;
  }>;
  decimals: ZodNumber;
  name: ZodString;
  symbol: ZodString;
}, "strip", ZodTypeAny, {
  address: {
     type: AddressType;
     value: `0x${string}`;
  };
  chainInfo: {
     chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
     name: string;
  };
  decimals: number;
  name: string;
  symbol: string;
}, {
  address: {
     type: AddressType;
     value: `0x${string}`;
  };
  chainInfo: {
     chainId: 1 | 10 | 146 | 999 | 8453 | 42161;
     name: string;
  };
  decimals: number;
  name: string;
  symbol: string;
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IToken.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IToken.ts#L43)

## Description

Zod schema for IToken
