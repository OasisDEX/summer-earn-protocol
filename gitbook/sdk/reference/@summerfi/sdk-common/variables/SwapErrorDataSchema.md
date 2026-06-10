# Variable: SwapErrorDataSchema

```ts
const SwapErrorDataSchema: ZodObject<{
  apiQuery: ZodString;
  message: ZodString;
  reason: ZodString;
  statusCode: ZodNumber;
  subtype: ZodNativeEnum<typeof SwapErrorType>;
  type: ZodLiteral<SwapError>;
}, "strip", ZodTypeAny, {
  apiQuery: string;
  message: string;
  reason: string;
  statusCode: number;
  subtype: SwapErrorType;
  type: SwapError;
}, {
  apiQuery: string;
  message: string;
  reason: string;
  statusCode: number;
  subtype: SwapErrorType;
  type: SwapError;
}>;
```

Defined in: [sdk/sdk-common/src/swap/interfaces/ISwapError.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/swap/interfaces/ISwapError.ts#L30)

## Description

Zod schema for ISwapError
