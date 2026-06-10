# Function: isTokenAmountData()

```ts
function isTokenAmountData(maybeTokenAmount): maybeTokenAmount is Readonly<{ amount: string; token: ITokenStanalone }>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:162](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L162)

## Parameters

### maybeTokenAmount

`unknown`

## Returns

`maybeTokenAmount is Readonly<{ amount: string; token: ITokenStanalone }>`

true if the object is an ITokenAmountData

## Description

Type guard for ITokenAmountData
