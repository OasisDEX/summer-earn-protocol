# Abstract Class: Position

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L16)

## Name

Position

## See

IPosition

## Extended by

- [`ArmadaPosition`](ArmadaPosition.md)
- [`LendingPosition`](LendingPosition.md)

## Implements

- [`IPosition`](../interfaces/IPosition.md)

## Constructors

### Constructor

```ts
protected new Position(_): Position;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L26)

SEALED CONSTRUCTOR

#### Parameters

##### \_

[`PositionParameters`](../type-aliases/PositionParameters.md)

#### Returns

`Position`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L18)

SIGNATURE

#### Implementation of

[`IPosition`](../interfaces/IPosition.md).[`[___signature__]`](../interfaces/IPosition.md#___signature__)

***

### id

```ts
abstract readonly id: IPositionId;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L22)

Unique identifier for the position inside the Summer.fi system

#### Implementation of

[`IPosition`](../interfaces/IPosition.md).[`id`](../interfaces/IPosition.md#id)

***

### pool

```ts
abstract readonly pool: IPool;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L23)

Pool where the position is opened

#### Implementation of

[`IPosition`](../interfaces/IPosition.md).[`pool`](../interfaces/IPosition.md#pool)

***

### type

```ts
abstract readonly type: PositionType;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L21)

ATTRIBUTES

#### Implementation of

[`IPosition`](../interfaces/IPosition.md).[`type`](../interfaces/IPosition.md#type)
