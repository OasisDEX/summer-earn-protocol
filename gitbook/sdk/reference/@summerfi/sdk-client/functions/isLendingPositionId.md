# Function: isLendingPositionId()

```ts
function isLendingPositionId(maybeLendingPositionId): maybeLendingPositionId is ILendingPositionId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPositionId.ts#L42)

## Parameters

### maybeLendingPositionId

`unknown`

Object to be checked

## Returns

`maybeLendingPositionId is ILendingPositionId`

true if the object is an ILendingPositionId

It also asserts the type so that TypeScript knows that the object is an ILendingPool

## Description

Type guard for ILendingPositionId
