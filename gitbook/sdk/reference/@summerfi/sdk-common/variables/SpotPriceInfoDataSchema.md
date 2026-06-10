# Variable: SpotPriceInfoDataSchema

```ts
const SpotPriceInfoDataSchema: ZodObject<{
  price: ZodObject<{
     base: ZodUnion<[ZodObject<{
        address: ZodObject<{
           type: ZodNativeEnum<...>;
           value: ZodType<..., ..., ...>;
         }, "strip", ZodTypeAny, {
           type: AddressType;
           value: `0x${(...)}`;
         }, {
           type: AddressType;
           value: `0x${(...)}`;
        }>;
        chainInfo: ZodObject<{
           chainId: ZodUnion<...>;
           name: ZodString;
         }, "strip", ZodTypeAny, {
           chainId: ... | ... | ... | ... | ... | ...;
           name: string;
         }, {
           chainId: ... | ... | ... | ... | ... | ...;
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
     }>, ZodNativeEnum<typeof FiatCurrency>]>;
     quote: ZodUnion<[ZodObject<{
        address: ZodObject<{
           type: ZodNativeEnum<...>;
           value: ZodType<..., ..., ...>;
         }, "strip", ZodTypeAny, {
           type: AddressType;
           value: `0x${(...)}`;
         }, {
           type: AddressType;
           value: `0x${(...)}`;
        }>;
        chainInfo: ZodObject<{
           chainId: ZodUnion<...>;
           name: ZodString;
         }, "strip", ZodTypeAny, {
           chainId: ... | ... | ... | ... | ... | ...;
           name: string;
         }, {
           chainId: ... | ... | ... | ... | ... | ...;
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
     }>, ZodNativeEnum<typeof FiatCurrency>]>;
     value: ZodString;
   }, "strip", ZodTypeAny, {
     base:   | {
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
      }
        | USD
        | EUR;
     quote:   | {
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
      }
        | USD
        | EUR;
     value: string;
   }, {
     base:   | {
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
      }
        | USD
        | EUR;
     quote:   | {
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
      }
        | USD
        | EUR;
     value: string;
  }>;
  provider: ZodNativeEnum<typeof OracleProviderType>;
  token: ZodObject<{
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
        chainId: ZodUnion<[ZodUnion<[ZodLiteral<...>, ZodLiteral<...>, ...ZodLiteral<(...)>[]]>, ZodUnion<[ZodLiteral<...>, ZodLiteral<...>, ...ZodLiteral<(...)>[]]>]>;
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
}, "strip", ZodTypeAny, {
  price: {
     base:   | {
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
      }
        | USD
        | EUR;
     quote:   | {
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
      }
        | USD
        | EUR;
     value: string;
  };
  provider: OracleProviderType;
  token: {
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
  };
}, {
  price: {
     base:   | {
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
      }
        | USD
        | EUR;
     quote:   | {
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
      }
        | USD
        | EUR;
     value: string;
  };
  provider: OracleProviderType;
  token: {
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
  };
}>;
```

Defined in: [sdk/sdk-common/src/oracle/ISpotPriceInfo.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/oracle/ISpotPriceInfo.ts#L22)

## Description

Zod schema for ISpotPriceInfo
