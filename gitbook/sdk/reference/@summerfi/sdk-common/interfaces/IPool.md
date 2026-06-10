# Interface: IPool

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L18)

## Name

IPool

## Description

Represents a generic protocol pool. Contains information about the pool's ID,
             which is specific to each protocol, and the pool's type

It is meant to be specialized for each type of pool

## Extends

- [`IPrintable`](IPrintable.md).[`IPoolData`](../type-aliases/IPoolData.md)

## Extended by

- [`IArmadaVault`](IArmadaVault.md)
- [`ILendingPool`](ILendingPool.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L20)

Signature to differentiate from similar interfaces

***

### id

```ts
readonly id: IPoolId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L24)

Unique identifier for the pool, to be specialized for each protocol

#### Overrides

```ts
IPoolData.id
```

***

### type

```ts
readonly type: PoolType;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L22)

Type of the pool

#### Overrides

```ts
IPoolData.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPrintable.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPrintable.ts#L15)

#### Returns

`string`

string

The string representation should have enough info to debug the object

#### Name

toString

#### Description

Returns a string representation of the object

#### Inherited from

[`IPrintable`](IPrintable.md).[`toString`](IPrintable.md#tostring)
