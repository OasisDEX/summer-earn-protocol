# Interface: IPoolInfo

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L16)

## Name

IPool

## Description

Represents the extended information of a pool. It should contain extra info that is common for any type of pool

It is meant to be specialized for each type of pool, like a lending pool, a staking pool, etc...

## Extends

- [`IPoolInfoData`](../type-aliases/IPoolInfoData.md)

## Extended by

- [`IArmadaVaultInfo`](IArmadaVaultInfo.md)
- [`ILendingPoolInfo`](ILendingPoolInfo.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L18)

Signature to differentiate from similar interfaces

***

### id

```ts
readonly id: IPoolId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L22)

Unique identifier for the pool, to be specialized for each protocol

#### Overrides

```ts
IPoolInfoData.id
```

***

### type

```ts
readonly type: PoolType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L20)

Type of the pool

#### Overrides

```ts
IPoolInfoData.type
```
