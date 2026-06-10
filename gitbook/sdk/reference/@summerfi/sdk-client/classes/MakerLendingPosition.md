# Class: MakerLendingPosition

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts#L19)

MakerPosition

## See

IMakerLendingPosition

## Extends

- [`LendingPosition`](LendingPosition.md)

## Implements

- `IMakerLendingPosition`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts#L21)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPosition.[___signature__]
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`[___signature__]`](LendingPosition.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L25)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPosition.[___signature__]
```

#### Inherited from

```ts
LendingPosition.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L18)

SIGNATURE

#### Implementation of

```ts
IMakerLendingPosition.[___signature__]
```

#### Inherited from

```ts
LendingPosition.[___signature__]
```

***

### collateralAmount

```ts
readonly collateralAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L31)

Amount of collateral deposited in the pool

#### Implementation of

```ts
IMakerLendingPosition.collateralAmount
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`collateralAmount`](LendingPosition.md#collateralamount)

***

### debtAmount

```ts
readonly debtAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L30)

Amount of debt borrowed from the pool

#### Implementation of

```ts
IMakerLendingPosition.debtAmount
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`debtAmount`](LendingPosition.md#debtamount)

***

### id

```ts
readonly id: IMakerLendingPositionId;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts#L24)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPosition.id
```

#### Overrides

[`LendingPosition`](LendingPosition.md).[`id`](LendingPosition.md#id)

***

### pool

```ts
readonly pool: IMakerLendingPool;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts#L25)

Pool where the position is

#### Implementation of

```ts
IMakerLendingPosition.pool
```

#### Overrides

[`LendingPosition`](LendingPosition.md).[`pool`](LendingPosition.md#pool)

***

### subtype

```ts
readonly subtype: LendingPositionType;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L28)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPosition.subtype
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`subtype`](LendingPosition.md#subtype)

***

### type

```ts
readonly type: Lending = PositionType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L33)

ATTRIBUTES

#### Implementation of

```ts
IMakerLendingPosition.type
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`type`](LendingPosition.md#type)

## Methods

### createFrom()

```ts
static createFrom(params): MakerLendingPosition;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/implementation/MakerLendingPosition.ts#L28)

FACTORY

#### Parameters

##### params

[`MakerLendingPositionParameters`](../type-aliases/MakerLendingPositionParameters.md)

#### Returns

`MakerLendingPosition`
