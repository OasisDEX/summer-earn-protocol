# Abstract Class: LendingPoolId

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L16)

LendingPoolId

## See

ILendingPoolId

## Extends

- `PoolId`

## Implements

- [`ILendingPoolId`](../interfaces/ILendingPoolId.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Constructors

### Constructor

```ts
protected new LendingPoolId(params): LendingPoolId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L24)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`LendingPoolIdParameters`](../type-aliases/LendingPoolIdParameters.md)

#### Returns

`LendingPoolId`

#### Overrides

```ts
PoolId.constructor
```

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L18)

SIGNATURE

#### Implementation of

[`ILendingPoolId`](../interfaces/ILendingPoolId.md).[`[___signature__]`](../interfaces/ILendingPoolId.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
ILendingPoolId.[___signature__]
```

#### Inherited from

```ts
PoolId.[___signature__]
```

***

### protocol

```ts
abstract readonly protocol: IProtocol;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L22)

Protocol where the pool is

#### Implementation of

[`ILendingPoolId`](../interfaces/ILendingPoolId.md).[`protocol`](../interfaces/ILendingPoolId.md#protocol)

#### Inherited from

```ts
PoolId.protocol
```

***

### type

```ts
readonly type: Lending = PoolType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L21)

ATTRIBUTES

#### Implementation of

[`ILendingPoolId`](../interfaces/ILendingPoolId.md).[`type`](../interfaces/ILendingPoolId.md#type)

#### Overrides

```ts
PoolId.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L31)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

#### Overrides

```ts
PoolId.toString
```
