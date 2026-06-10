# Function: isLendingPoolInfo()

```ts
function isLendingPoolInfo(maybePool): maybePool is ILendingPoolInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:62](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L62)

## Parameters

### maybePool

`unknown`

Object to be checked

## Returns

`maybePool is ILendingPoolInfo`

true if the object is an ILendingPool

It also asserts the type so that TypeScript knows that the object is an ILendingPool

## Description

Type guard for ILendingPoolInfo
