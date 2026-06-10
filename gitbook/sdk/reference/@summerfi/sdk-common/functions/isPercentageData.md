# Function: isPercentageData()

```ts
function isPercentageData(maybePercentageData, returnedErrors?): maybePercentageData is Readonly<{ value: number }>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPercentage.ts:94](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPercentage.ts#L94)

## Parameters

### maybePercentageData

`unknown`

### returnedErrors?

`string`[]

## Returns

`maybePercentageData is Readonly<{ value: number }>`

true if the object is an IPercentageData

## Description

Type guard for IPercentageData
