# Abstract Class: LendingPosition

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L23)

## Name

LendingPosition

## See

ILendingPosition

## Extends

- [`Position`](Position.md)

## Extended by

- [`ExternalLendingPosition`](ExternalLendingPosition.md)

## Implements

- [`ILendingPosition`](../interfaces/ILendingPosition.md)

## Constructors

### Constructor

```ts
protected new LendingPosition(params): LendingPosition;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L36)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`LendingPositionParameters`](../type-aliases/LendingPositionParameters.md)

#### Returns

`LendingPosition`

#### Overrides

[`Position`](Position.md).[`constructor`](Position.md#constructor)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L25)

SIGNATURE

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`[___signature__]`](../interfaces/ILendingPosition.md#___signature__-1)

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
ILendingPosition.[___signature__]
```

#### Inherited from

```ts
Position.[___signature__]
```

***

### collateralAmount

```ts
readonly collateralAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L31)

Amount of collateral deposited in the pool

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`collateralAmount`](../interfaces/ILendingPosition.md#collateralamount)

***

### debtAmount

```ts
readonly debtAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L30)

Amount of debt borrowed from the pool

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`debtAmount`](../interfaces/ILendingPosition.md#debtamount)

***

### id

```ts
readonly id: ILendingPositionId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L29)

Unique identifier for the position inside the Summer.fi system

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`id`](../interfaces/ILendingPosition.md#id)

#### Overrides

[`Position`](Position.md).[`id`](Position.md#id)

***

### pool

```ts
abstract readonly pool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L32)

Pool where the position is

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`pool`](../interfaces/ILendingPosition.md#pool)

#### Overrides

[`Position`](Position.md).[`pool`](Position.md#pool)

***

### subtype

```ts
readonly subtype: LendingPositionType;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L28)

ATTRIBUTES

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`subtype`](../interfaces/ILendingPosition.md#subtype)

***

### type

```ts
readonly type: Lending = PositionType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L33)

ATTRIBUTES

#### Implementation of

[`ILendingPosition`](../interfaces/ILendingPosition.md).[`type`](../interfaces/ILendingPosition.md#type)

#### Overrides

[`Position`](Position.md).[`type`](Position.md#type)
