# Abstract Class: PositionId

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L14)

PositionId

## See

IPositionIdData

## Extended by

- [`ArmadaPositionId`](ArmadaPositionId.md)
- [`LendingPositionId`](LendingPositionId.md)

## Implements

- [`IPositionId`](../interfaces/IPositionId.md)

## Constructors

### Constructor

```ts
protected new PositionId(params): PositionId;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L23)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`PositionIdParameters`](../type-aliases/PositionIdParameters.md)

#### Returns

`PositionId`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L16)

SIGNATURE

#### Implementation of

[`IPositionId`](../interfaces/IPositionId.md).[`[___signature__]`](../interfaces/IPositionId.md#___signature__)

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

[`IPositionId`](../interfaces/IPositionId.md).[`id`](../interfaces/IPositionId.md#id)

***

### type

```ts
abstract readonly type: PositionType;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L20)

Type of the position

#### Implementation of

[`IPositionId`](../interfaces/IPositionId.md).[`type`](../interfaces/IPositionId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L30)

#### Returns

`string`

#### See

IPrintable.toString
