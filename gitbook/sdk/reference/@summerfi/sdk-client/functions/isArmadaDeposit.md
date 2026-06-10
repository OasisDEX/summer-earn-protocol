# Function: isArmadaDeposit()

```ts
function isArmadaDeposit(maybeArmadaDeposit, returnedErrors?): maybeArmadaDeposit is Readonly<{ amount: ITokenAmount; amountUsd: IFiatCurrencyAmount; from: `0x${string}`; timestamp: number; to: `0x${string}`; txHash: `0x${string}`; vaultBalance: ITokenAmount; vaultBalanceUsd: IFiatCurrencyAmount }>;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDeposit.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDeposit.ts#L32)

## Parameters

### maybeArmadaDeposit

`unknown`

Object to be checked

### returnedErrors?

`string`[]

## Returns

`` maybeArmadaDeposit is Readonly<{ amount: ITokenAmount; amountUsd: IFiatCurrencyAmount; from: `0x${string}`; timestamp: number; to: `0x${string}`; txHash: `0x${string}`; vaultBalance: ITokenAmount; vaultBalanceUsd: IFiatCurrencyAmount }> ``

true if the object is an IArmadaDeposit

## Description

Type guard for IArmadaDeposit
