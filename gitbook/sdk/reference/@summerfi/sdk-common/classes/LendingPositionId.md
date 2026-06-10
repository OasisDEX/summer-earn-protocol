# Abstract Class: LendingPositionId

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L15)

LendingPositionId

## See

ILendingPositionId

## Extends

- [`PositionId`](PositionId.md)

## Extended by

- [`ExternalLendingPositionId`](ExternalLendingPositionId.md)

## Implements

- [`ILendingPositionIdData`](../type-aliases/ILendingPositionIdData.md)

## Constructors

### Constructor

```ts
protected new LendingPositionId(params): LendingPositionId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L23)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`LendingPositionIdParameters`](../type-aliases/LendingPositionIdParameters.md)

#### Returns

`LendingPositionId`

#### Overrides

[`PositionId`](PositionId.md).[`constructor`](PositionId.md#constructor)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L17)

SIGNATURE

#### Inherited from

[`PositionId`](PositionId.md).[`[___signature__]`](PositionId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L16)

SIGNATURE

#### Inherited from

```ts
PositionId.[___signature__]
```

***

### id

```ts
readonly id: string;
```

Defined in: [sdk/sdk-common/src/common/implementation/PositionId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PositionId.ts#L19)

ATTRIBUTES

#### Implementation of

```ts
ILendingPositionIdData.id
```

#### Inherited from

[`PositionId`](PositionId.md).[`id`](PositionId.md#id)

***

### type

```ts
readonly type: Lending = PositionType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L20)

ATTRIBUTES

#### Implementation of

```ts
ILendingPositionIdData.type
```

#### Overrides

[`PositionId`](PositionId.md).[`type`](PositionId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPositionId.ts#L30)

#### Returns

`string`

#### See

IPrintable.toString

#### Overrides

[`PositionId`](PositionId.md).[`toString`](PositionId.md#tostring)
