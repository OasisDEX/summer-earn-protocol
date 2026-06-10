# Interface: IArmadaVaultInfo

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L21)

IArmadaVaultInfo

## Description

Interface for an the extended info of an Armada Protocol vault (fleet)

## Extends

- [`IPoolInfo`](IPoolInfo.md).[`IArmadaVaultInfoData`](../type-aliases/IArmadaVaultInfoData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L23)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`IPoolInfo`](IPoolInfo.md).[`[___signature__]`](IPoolInfo.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L18)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPoolInfo.[___signature__]
```

***

### apy

```ts
readonly apy: IPercentage | null;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L39)

Vault apy

#### Overrides

```ts
IArmadaVaultInfoData.apy
```

***

### apys

```ts
readonly apys: VaultApys;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:41](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L41)

Vault apys for different time periods

#### Overrides

```ts
IArmadaVaultInfoData.apys
```

***

### assetToken

```ts
readonly assetToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L29)

Underlying asset token that can be deposited into the vault

#### Overrides

```ts
IArmadaVaultInfoData.assetToken
```

***

### depositCap

```ts
readonly depositCap: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L31)

Maximum amount that can be deposited into the vault at this moment

#### Overrides

```ts
IArmadaVaultInfoData.depositCap
```

***

### id

```ts
readonly id: IArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L25)

ID of the vault

#### Overrides

[`IPoolInfo`](IPoolInfo.md).[`id`](IPoolInfo.md#id)

***

### merklRewards

```ts
readonly merklRewards: object[] | undefined;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L50)

Vault Merkl rewards apy

#### Overrides

```ts
IArmadaVaultInfoData.merklRewards
```

***

### rewardsApys

```ts
readonly rewardsApys: object[] | undefined;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L43)

Vault SUMR rewards apy

#### Overrides

```ts
IArmadaVaultInfoData.rewardsApys
```

***

### sharePrice

```ts
readonly sharePrice: IPrice;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L37)

Current price per share of the vault

#### Overrides

```ts
IArmadaVaultInfoData.sharePrice
```

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L27)

Token of the vault

#### Overrides

```ts
IArmadaVaultInfoData.token
```

***

### totalDeposits

```ts
readonly totalDeposits: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L33)

Total amount of assets currently deposited in the vault

#### Overrides

```ts
IArmadaVaultInfoData.totalDeposits
```

***

### totalShares

```ts
readonly totalShares: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L35)

Total amount of shares currently minted in the vault

#### Overrides

```ts
IArmadaVaultInfoData.totalShares
```

***

### tvlUsd

```ts
readonly tvlUsd: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:57](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L57)

Total value locked in USD

#### Overrides

```ts
IArmadaVaultInfoData.tvlUsd
```

***

### type

```ts
readonly type: Armada;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts:60](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaVaultInfo.ts#L60)

Type of the pool

#### Overrides

[`IPoolInfo`](IPoolInfo.md).[`type`](IPoolInfo.md#type)
