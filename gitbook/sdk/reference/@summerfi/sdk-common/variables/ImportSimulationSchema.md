# Variable: ImportSimulationSchema

```ts
const ImportSimulationSchema: ZodObject<{
  sourcePosition: ZodType<IExternalLendingPosition, ZodTypeDef, IExternalLendingPosition>;
  steps: ZodArray<ZodType<Steps, ZodTypeDef, Steps>, "many">;
  targetPosition: ZodType<ILendingPosition, ZodTypeDef, ILendingPosition>;
  type: ZodLiteral<ImportPosition>;
}, "strip", ZodTypeAny, {
  sourcePosition: IExternalLendingPosition;
  steps: Steps[];
  targetPosition: ILendingPosition;
  type: ImportPosition;
}, {
  sourcePosition: IExternalLendingPosition;
  steps: Steps[];
  targetPosition: ILendingPosition;
  type: ImportPosition;
}>;
```

Defined in: [sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts:40](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/simulation/interfaces/IImportSimulation.ts#L40)

## Description

Zod schema for IImportSimulation
