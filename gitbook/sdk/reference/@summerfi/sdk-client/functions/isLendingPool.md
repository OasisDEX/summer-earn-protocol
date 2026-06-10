# Function: isLendingPool()

```ts
function isLendingPool(maybePool): maybePool is ILendingPool;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:59](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L59)

## Parameters

### maybePool

`unknown`

Object to be checked

## Returns

`maybePool is ILendingPool`

true if the object is an ILendingPool

It also asserts the type so that TypeScript knows that the object is an ILendingPool

## Description

Type guard for ILendingPool
