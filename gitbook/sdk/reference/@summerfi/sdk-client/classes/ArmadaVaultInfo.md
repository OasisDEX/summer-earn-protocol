# Class: ArmadaVaultInfo

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L23)

ArmadaVaultInfo

## See

IArmadaVaultInfo

## Extends

- `PoolInfo`

## Implements

- [`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L25)

SIGNATURE

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`[___signature__]`](../interfaces/IArmadaVaultInfo.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolInfo.ts#L18)

SIGNATURE

#### Implementation of

```ts
IArmadaVaultInfo.[___signature__]
```

#### Inherited from

[`LendingPoolInfo`](LendingPoolInfo.md).[`[___signature__]`](LendingPoolInfo.md#___signature__-1)

***

### apy

```ts
readonly apy: IPercentage | null;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L36)

Vault apy

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`apy`](../interfaces/IArmadaVaultInfo.md#apy)

***

### apys

```ts
readonly apys: VaultApys;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L37)

Vault apys for different time periods

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`apys`](../interfaces/IArmadaVaultInfo.md#apys)

***

### assetToken

```ts
readonly assetToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L31)

Underlying asset token that can be deposited into the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`assetToken`](../interfaces/IArmadaVaultInfo.md#assettoken)

***

### depositCap

```ts
readonly depositCap: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L32)

Maximum amount that can be deposited into the vault at this moment

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`depositCap`](../interfaces/IArmadaVaultInfo.md#depositcap)

***

### id

```ts
readonly id: IArmadaVaultId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L29)

ID of the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`id`](../interfaces/IArmadaVaultInfo.md#id)

#### Overrides

```ts
PoolInfo.id
```

***

### merklRewards

```ts
readonly merklRewards: object[] | undefined;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L44)

Vault Merkl rewards apy

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`merklRewards`](../interfaces/IArmadaVaultInfo.md#merklrewards)

***

### rewardsApys

```ts
readonly rewardsApys: object[] | undefined;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L38)

Vault SUMR rewards apy

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`rewardsApys`](../interfaces/IArmadaVaultInfo.md#rewardsapys)

***

### sharePrice

```ts
readonly sharePrice: IPrice;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L35)

Current price per share of the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`sharePrice`](../interfaces/IArmadaVaultInfo.md#shareprice)

***

### token

```ts
readonly token: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L30)

Token of the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`token`](../interfaces/IArmadaVaultInfo.md#token)

***

### totalDeposits

```ts
readonly totalDeposits: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L33)

Total amount of assets currently deposited in the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`totalDeposits`](../interfaces/IArmadaVaultInfo.md#totaldeposits)

***

### totalShares

```ts
readonly totalShares: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L34)

Total amount of shares currently minted in the vault

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`totalShares`](../interfaces/IArmadaVaultInfo.md#totalshares)

***

### tvlUsd

```ts
readonly tvlUsd: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L50)

Total value locked in USD

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`tvlUsd`](../interfaces/IArmadaVaultInfo.md#tvlusd)

***

### type

```ts
readonly type: Armada = PoolType.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L28)

ATTRIBUTES

#### Implementation of

[`IArmadaVaultInfo`](../interfaces/IArmadaVaultInfo.md).[`type`](../interfaces/IArmadaVaultInfo.md#type)

#### Overrides

```ts
PoolInfo.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolInfo.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolInfo.ts#L32)

#### Returns

`string`

#### See

IPrintable.toString

#### Inherited from

```ts
PoolInfo.toString
```

***

### createFrom()

```ts
static createFrom(params): ArmadaVaultInfo;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts:53](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaVaultInfo.ts#L53)

FACTORY

#### Parameters

##### params

[`ArmadaVaultInfoParameters`](../type-aliases/ArmadaVaultInfoParameters.md)

#### Returns

`ArmadaVaultInfo`
