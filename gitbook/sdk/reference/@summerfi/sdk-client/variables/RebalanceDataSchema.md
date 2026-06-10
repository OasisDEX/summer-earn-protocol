# Variable: RebalanceDataSchema

```ts
const RebalanceDataSchema: ZodObject<{
  amount: ZodObject<{
     amount: ZodString;
     token: ZodType<ITokenStanalone, ZodTypeDef, ITokenStanalone>;
   }, "strip", ZodTypeAny, {
     amount: string;
     token: ITokenStanalone;
   }, {
     amount: string;
     token: ITokenStanalone;
  }>;
  fromArk: ZodObject<{
     type: ZodNativeEnum<typeof AddressType>;
     value: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
   }, "strip", ZodTypeAny, {
     type: AddressType;
     value: `0x${string}`;
   }, {
     type: AddressType;
     value: `0x${string}`;
  }>;
  toArk: ZodObject<{
     type: ZodNativeEnum<typeof AddressType>;
     value: ZodType<`0x${string}`, ZodTypeDef, `0x${string}`>;
   }, "strip", ZodTypeAny, {
     type: AddressType;
     value: `0x${string}`;
   }, {
     type: AddressType;
     value: `0x${string}`;
  }>;
}, "strip", ZodTypeAny, {
  amount: {
     amount: string;
     token: ITokenStanalone;
  };
  fromArk: {
     type: AddressType;
     value: `0x${string}`;
  };
  toArk: {
     type: AddressType;
     value: `0x${string}`;
  };
}, {
  amount: {
     amount: string;
     token: ITokenStanalone;
  };
  fromArk: {
     type: AddressType;
     value: `0x${string}`;
  };
  toArk: {
     type: AddressType;
     value: `0x${string}`;
  };
}>;
```

Defined in: [sdk/sdk-common/src/common/types/IRebalanceData.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/types/IRebalanceData.ts#L29)

## Description

Zod schema for IRebalanceData
