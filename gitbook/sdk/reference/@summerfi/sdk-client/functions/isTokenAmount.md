# Function: isTokenAmount()

```ts
function isTokenAmount(maybeTokenAmount, returnedErrors?): maybeTokenAmount is ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/ITokenAmount.ts:144](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/ITokenAmount.ts#L144)

## Parameters

### maybeTokenAmount

`unknown`

### returnedErrors?

`string`[]

## Returns

`maybeTokenAmount is ITokenAmount`

true if the object is an ITokenAmount

## Description

Type guard for ITokenAmount
