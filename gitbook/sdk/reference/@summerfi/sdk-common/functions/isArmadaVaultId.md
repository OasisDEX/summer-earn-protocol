# Function: isArmadaVaultId()

```ts
function isArmadaVaultId(maybeArmadaVaultId, returnedErrors?): maybeArmadaVaultId is IArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts:51](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultId.ts#L51)

## Parameters

### maybeArmadaVaultId

`unknown`

Object to be checked

### returnedErrors?

`string`[]

## Returns

`maybeArmadaVaultId is IArmadaVaultId`

true if the object is a IMakerLendingPosition

## Description

Type guard for IArmadaVaultId
