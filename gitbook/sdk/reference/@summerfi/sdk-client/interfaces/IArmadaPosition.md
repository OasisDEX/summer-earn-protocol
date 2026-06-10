# Interface: IArmadaPosition

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L18)

IArmadaPosition

## Description

Interface for an Armada Protocol position

## Extends

- [`IPosition`](IPosition.md).[`IArmadaPositionData`](../type-aliases/IArmadaPositionData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L20)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`IPosition`](IPosition.md).[`[___signature__]`](IPosition.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPosition.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPosition.ts#L17)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPosition.[___signature__]
```

***

### ~~amount~~

```ts
readonly amount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:65](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L65)

#### Deprecated

Use assets instead

#### Overrides

```ts
IArmadaPositionData.amount
```

***

### assetPriceUSD

```ts
readonly assetPriceUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L28)

Asset price in USD

#### Overrides

```ts
IArmadaPositionData.assetPriceUSD
```

***

### assets

```ts
readonly assets: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L26)

Assets balance

#### Overrides

```ts
IArmadaPositionData.assets
```

***

### assetsUSD

```ts
readonly assetsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L30)

Assets value in USD

#### Overrides

```ts
IArmadaPositionData.assetsUSD
```

***

### claimableSummerToken

```ts
readonly claimableSummerToken: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:55](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L55)

Claimable SUMR rewards

#### Overrides

```ts
IArmadaPositionData.claimableSummerToken
```

***

### claimedSummerToken

```ts
readonly claimedSummerToken: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:53](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L53)

Claimed SUMR rewards

#### Overrides

```ts
IArmadaPositionData.claimedSummerToken
```

***

### deposits

```ts
readonly deposits: object[];
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:101](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L101)

#### amount

```ts
amount: ITokenAmount;
```

#### timestamp

```ts
timestamp: number;
```

#### Inherited from

```ts
IArmadaPositionData.deposits
```

***

### depositsAmount

```ts
readonly depositsAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L35)

Total assets deposited in the Fleet

#### Overrides

```ts
IArmadaPositionData.depositsAmount
```

***

### depositsAmountUSD

```ts
readonly depositsAmountUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L37)

Total assets deposited in the Fleet in USD

#### Overrides

```ts
IArmadaPositionData.depositsAmountUSD
```

***

### earnings

```ts
readonly earnings: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:48](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L48)

Earnings (amount - netDeposits)

#### Overrides

```ts
IArmadaPositionData.earnings
```

***

### earningsUSD

```ts
readonly earningsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L50)

Earnings in USD

#### Overrides

```ts
IArmadaPositionData.earningsUSD
```

***

### id

```ts
readonly id: IArmadaPositionId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L22)

ID of the position

#### Overrides

[`IPosition`](IPosition.md).[`id`](IPosition.md#id)

***

### netDeposits

```ts
readonly netDeposits: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L44)

Net deposits (deposits - withdrawals)

#### Overrides

```ts
IArmadaPositionData.netDeposits
```

***

### netDepositsUSD

```ts
readonly netDepositsUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:46](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L46)

Net deposits in USD

#### Overrides

```ts
IArmadaPositionData.netDepositsUSD
```

***

### pool

```ts
readonly pool: IArmadaVault;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L24)

Pool where the position is opened

#### Overrides

[`IPosition`](IPosition.md).[`pool`](IPosition.md#pool)

***

### rewards

```ts
readonly rewards: object[];
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:57](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L57)

Reward assets for this position

#### claimable

```ts
claimable: ITokenAmount;
```

#### claimed

```ts
claimed: ITokenAmount;
```

#### Overrides

```ts
IArmadaPositionData.rewards
```

***

### shares

```ts
readonly shares: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L32)

Number of shares allocated to this position

#### Overrides

```ts
IArmadaPositionData.shares
```

***

### type

```ts
readonly type: Armada;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:62](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L62)

Type of the position in the Summer.fi system

#### Overrides

[`IPosition`](IPosition.md).[`type`](IPosition.md#type)

***

### withdrawals

```ts
readonly withdrawals: object[];
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:105](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L105)

#### amount

```ts
amount: ITokenAmount;
```

#### timestamp

```ts
timestamp: number;
```

#### Inherited from

```ts
IArmadaPositionData.withdrawals
```

***

### withdrawalsAmount

```ts
readonly withdrawalsAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L39)

Total assets withdrawn from the Fleet

#### Overrides

```ts
IArmadaPositionData.withdrawalsAmount
```

***

### withdrawalsAmountUSD

```ts
readonly withdrawalsAmountUSD: IFiatCurrencyAmount;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts:41](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaPosition.ts#L41)

Total assets withdrawn from the Fleet in USD

#### Overrides

```ts
IArmadaPositionData.withdrawalsAmountUSD
```
