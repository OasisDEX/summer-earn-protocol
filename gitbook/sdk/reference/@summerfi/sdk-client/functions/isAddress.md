# Function: isAddress()

```ts
function isAddress(maybeAddress, returnedErrors?): maybeAddress is IAddress;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IAddress.ts:56](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IAddress.ts#L56)

## Parameters

### maybeAddress

`unknown`

### returnedErrors?

`string`[]

## Returns

`maybeAddress is IAddress`

true if the object is an IAddress

## Description

Type guard for IAddress
