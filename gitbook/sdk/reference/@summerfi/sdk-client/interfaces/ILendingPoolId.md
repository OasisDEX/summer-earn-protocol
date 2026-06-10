# Interface: ILendingPoolId

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L21)

## Name

ILendingPoolId

## Description

Identifies a generic lending pool. This will be specialized for each protocol

This is meant to be used for single pair collateral/debt lending pools. For multi-collateral pools,
a different interface should be used

Note: Typescript forces the interface to re-declare any properties that have different BUT compatible types.
This may be fixed eventually, there is a discussion on the topic here: https://github.com/microsoft/TypeScript/issues/16936

## Extends

- [`IPoolId`](IPoolId.md).[`ILendingPoolIdData`](../type-aliases/ILendingPoolIdData.md)

## Extended by

- [`IAaveV3LendingPoolId`](IAaveV3LendingPoolId.md)
- [`IMakerLendingPoolId`](IMakerLendingPoolId.md)
- [`IMorphoLendingPoolId`](IMorphoLendingPoolId.md)
- [`ISparkLendingPoolId`](ISparkLendingPoolId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L23)

Signature to differentiate it from other interfaces

#### Inherited from

[`IPoolId`](IPoolId.md).[`[___signature__]`](IPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L19)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPoolId.[___signature__]
```

***

### protocol

```ts
readonly protocol: IProtocol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L25)

Protocol where the pool is

#### Overrides

[`IPoolId`](IPoolId.md).[`protocol`](IPoolId.md#protocol)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L28)

Pool type

#### Overrides

[`IPoolId`](IPoolId.md).[`type`](IPoolId.md#type)
