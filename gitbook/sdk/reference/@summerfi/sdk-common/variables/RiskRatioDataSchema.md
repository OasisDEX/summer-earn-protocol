# Variable: RiskRatioDataSchema

```ts
const RiskRatioDataSchema: ZodObject<{
  type: ZodNativeEnum<typeof RiskRatioType>;
  value: ZodUnion<[ZodObject<{
     value: ZodNumber;
   }, "strip", ZodTypeAny, {
     value: number;
   }, {
     value: number;
  }>, ZodNumber]>;
}, "strip", ZodTypeAny, {
  type: RiskRatioType;
  value:   | number
     | {
     value: number;
   };
}, {
  type: RiskRatioType;
  value:   | number
     | {
     value: number;
   };
}>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IRiskRatio.ts:48](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IRiskRatio.ts#L48)

## Description

Zod schema for IRiskRatioData
