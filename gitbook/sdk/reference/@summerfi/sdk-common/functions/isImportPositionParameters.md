# Function: isImportPositionParameters()

```ts
function isImportPositionParameters(maybeImportPositionParameters): maybeImportPositionParameters is Readonly<{ externalPosition: IExternalLendingPosition }>;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IImportPositionParameters.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IImportPositionParameters.ts#L39)

## Parameters

### maybeImportPositionParameters

`unknown`

## Returns

`maybeImportPositionParameters is Readonly<{ externalPosition: IExternalLendingPosition }>`

true if the object is an IImportPositionParameters

## Description

Type guard for IImportPositionParameters
