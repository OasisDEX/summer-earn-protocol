# Class: ExternalLendingPosition

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L20)

## Name

ExternalLendingPosition

## See

IExternalLendingPosition

## Extends

- [`LendingPosition`](LendingPosition.md)

## Implements

- [`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L22)

SIGNATURE

#### Implementation of

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`[___signature__]`](../interfaces/IExternalLendingPosition.md#___signature__-2)

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
IExternalLendingPosition.[___signature__]
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
IExternalLendingPosition.[___signature__]
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

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`collateralAmount`](../interfaces/IExternalLendingPosition.md#collateralamount)

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

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`debtAmount`](../interfaces/IExternalLendingPosition.md#debtamount)

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`debtAmount`](LendingPosition.md#debtamount)

***

### id

```ts
readonly id: IExternalLendingPositionId;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L25)

ATTRIBUTES

#### Implementation of

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`id`](../interfaces/IExternalLendingPosition.md#id)

#### Overrides

[`LendingPosition`](LendingPosition.md).[`id`](LendingPosition.md#id)

***

### pool

```ts
readonly pool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L26)

Pool where the position is

#### Implementation of

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`pool`](../interfaces/IExternalLendingPosition.md#pool)

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

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`subtype`](../interfaces/IExternalLendingPosition.md#subtype)

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

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`type`](../interfaces/IExternalLendingPosition.md#type)

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`type`](LendingPosition.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:44](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L44)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IExternalLendingPosition`](../interfaces/IExternalLendingPosition.md).[`toString`](../interfaces/IExternalLendingPosition.md#tostring)

***

### createFrom()

```ts
static createFrom(params): ExternalLendingPosition;
```

Defined in: [sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/implementation/ExternalLendingPosition.ts#L29)

FACTORY

#### Parameters

##### params

[`ExternalLendingPositionParameters`](../type-aliases/ExternalLendingPositionParameters.md)

#### Returns

`ExternalLendingPosition`
