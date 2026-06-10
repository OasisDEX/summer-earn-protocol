# Interface: IPoolId

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L17)

## Name

IPoolId

## Description

Represents a pool's ID. This will be specialized for each protocol

It is a way to retrieve a pool from the protocol and it should include all the necessary information
to uniquely identify a pool

## Extends

- [`IPoolIdData`](../type-aliases/IPoolIdData.md)

## Extended by

- [`IArmadaVaultId`](IArmadaVaultId.md)
- [`ILendingPoolId`](ILendingPoolId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L19)

Signature to differentiate from similar interfaces

***

### protocol

```ts
readonly protocol: IProtocol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L23)

Protocol where the pool is

#### Overrides

```ts
IPoolIdData.protocol
```

***

### type

```ts
readonly type: PoolType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L21)

Pool type

#### Overrides

```ts
IPoolIdData.type
```
