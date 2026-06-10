# Class: ArmadaPosition

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L20)

ArmadaPosition

## See

IArmadaPosition

## Extends

- [`Position`](Position.md)

## Implements

- [`IArmadaPosition`](../interfaces/IArmadaPosition.md)

## Constructors

### Constructor

```ts
protected new ArmadaPosition(params): ArmadaPosition;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:60](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L60)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`ArmadaPositionParameters`](../type-aliases/ArmadaPositionParameters.md)

#### Returns

`ArmadaPosition`

#### Overrides

[`Position`](Position.md).[`constructor`](Position.md#constructor)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L22)

SIGNATURE

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`[___signature__]`](../interfaces/IArmadaPosition.md#___signature__-1)

#### Inherited from

[`Position`](Position.md).[`[___signature__]`](Position.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L18)

SIGNATURE

#### Implementation of

```ts
IArmadaPosition.[___signature__]
```

#### Inherited from

```ts
Position.[___signature__]
```

***

### ~~amount~~

```ts
readonly amount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:48](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L48)

#### Deprecated

Use assets instead

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`amount`](../interfaces/IArmadaPosition.md#amount)

***

### assetPriceUSD

```ts
readonly assetPriceUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L29)

Asset price in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`assetPriceUSD`](../interfaces/IArmadaPosition.md#assetpriceusd)

***

### assets

```ts
readonly assets: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L28)

Assets balance

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`assets`](../interfaces/IArmadaPosition.md#assets)

***

### assetsUSD

```ts
readonly assetsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L30)

Assets value in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`assetsUSD`](../interfaces/IArmadaPosition.md#assetsusd)

***

### claimableSummerToken

```ts
readonly claimableSummerToken: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:41](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L41)

Claimable SUMR rewards

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`claimableSummerToken`](../interfaces/IArmadaPosition.md#claimablesummertoken)

***

### claimedSummerToken

```ts
readonly claimedSummerToken: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:40](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L40)

Claimed SUMR rewards

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`claimedSummerToken`](../interfaces/IArmadaPosition.md#claimedsummertoken)

***

### ~~deposits~~

```ts
readonly deposits: object[];
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L50)

#### ~~amount~~

```ts
amount: ITokenAmount;
```

#### ~~timestamp~~

```ts
timestamp: number;
```

#### Deprecated

do not use

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`deposits`](../interfaces/IArmadaPosition.md#deposits)

***

### depositsAmount

```ts
readonly depositsAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L32)

Total assets deposited in the Fleet

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`depositsAmount`](../interfaces/IArmadaPosition.md#depositsamount)

***

### depositsAmountUSD

```ts
readonly depositsAmountUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L33)

Total assets deposited in the Fleet in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`depositsAmountUSD`](../interfaces/IArmadaPosition.md#depositsamountusd)

***

### earnings

```ts
readonly earnings: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L38)

Earnings (amount - netDeposits)

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`earnings`](../interfaces/IArmadaPosition.md#earnings)

***

### earningsUSD

```ts
readonly earningsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L39)

Earnings in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`earningsUSD`](../interfaces/IArmadaPosition.md#earningsusd)

***

### id

```ts
readonly id: IArmadaPositionId;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L26)

ID of the position

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`id`](../interfaces/IArmadaPosition.md#id)

#### Overrides

[`Position`](Position.md).[`id`](Position.md#id)

***

### netDeposits

```ts
readonly netDeposits: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L36)

Net deposits (deposits - withdrawals)

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`netDeposits`](../interfaces/IArmadaPosition.md#netdeposits)

***

### netDepositsUSD

```ts
readonly netDepositsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L37)

Net deposits in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`netDepositsUSD`](../interfaces/IArmadaPosition.md#netdepositsusd)

***

### pool

```ts
readonly pool: IArmadaVault;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L27)

Pool where the position is opened

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`pool`](../interfaces/IArmadaPosition.md#pool)

#### Overrides

[`Position`](Position.md).[`pool`](Position.md#pool)

***

### rewards

```ts
readonly rewards: object[];
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L42)

Reward assets for this position

#### claimable

```ts
claimable: ITokenAmount;
```

#### claimed

```ts
claimed: ITokenAmount;
```

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`rewards`](../interfaces/IArmadaPosition.md#rewards)

***

### shares

```ts
readonly shares: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L31)

Number of shares allocated to this position

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`shares`](../interfaces/IArmadaPosition.md#shares)

***

### type

```ts
readonly type: Armada = PositionType.Armada;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L25)

ATTRIBUTES

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`type`](../interfaces/IArmadaPosition.md#type)

#### Overrides

[`Position`](Position.md).[`type`](Position.md#type)

***

### ~~withdrawals~~

```ts
readonly withdrawals: object[];
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:52](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L52)

#### ~~amount~~

```ts
amount: ITokenAmount;
```

#### ~~timestamp~~

```ts
timestamp: number;
```

#### Deprecated

do not use

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`withdrawals`](../interfaces/IArmadaPosition.md#withdrawals)

***

### withdrawalsAmount

```ts
readonly withdrawalsAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L34)

Total assets withdrawn from the Fleet

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`withdrawalsAmount`](../interfaces/IArmadaPosition.md#withdrawalsamount)

***

### withdrawalsAmountUSD

```ts
readonly withdrawalsAmountUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L35)

Total assets withdrawn from the Fleet in USD

#### Implementation of

[`IArmadaPosition`](../interfaces/IArmadaPosition.md).[`withdrawalsAmountUSD`](../interfaces/IArmadaPosition.md#withdrawalsamountusd)

## Methods

### createFrom()

```ts
static createFrom(params): ArmadaPosition;
```

Defined in: [sdk/sdk-common/src/common/implementation/ArmadaPosition.ts:55](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ArmadaPosition.ts#L55)

FACTORY

#### Parameters

##### params

[`ArmadaPositionParameters`](../type-aliases/ArmadaPositionParameters.md)

#### Returns

`ArmadaPosition`
