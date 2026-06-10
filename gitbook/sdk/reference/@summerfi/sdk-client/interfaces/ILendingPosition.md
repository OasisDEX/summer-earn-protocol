# Interface: ILendingPosition

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L18)

## Name

ILendingPosition

## Description

Represents a position in a Lending protocol

## Extends

- [`IPosition`](IPosition.md).[`ILendingPositionData`](../type-aliases/ILendingPositionData.md)

## Extended by

- [`IExternalLendingPosition`](IExternalLendingPosition.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L20)

Signature to differentiate from similar interfaces

#### Inherited from

[`IPosition`](IPosition.md).[`[___signature__]`](IPosition.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPosition.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPosition.ts#L17)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPosition.[___signature__]
```

***

### collateralAmount

```ts
readonly collateralAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L28)

Amount of collateral deposited in the pool

#### Overrides

```ts
ILendingPositionData.collateralAmount
```

***

### debtAmount

```ts
readonly debtAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L26)

Amount of debt borrowed from the pool

#### Overrides

```ts
ILendingPositionData.debtAmount
```

***

### id

```ts
readonly id: ILendingPositionId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L24)

Unique identifier for the position inside the Summer.fi system

#### Overrides

[`IPosition`](IPosition.md).[`id`](IPosition.md#id)

***

### pool

```ts
readonly pool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L30)

Pool where the position is

#### Overrides

[`IPosition`](IPosition.md).[`pool`](IPosition.md#pool)

***

### subtype

```ts
readonly subtype: LendingPositionType;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L22)

Subtype of the position in the Summer.fi system

#### Overrides

```ts
ILendingPositionData.subtype
```

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L33)

Type of the position in the Summer.fi system

#### Overrides

[`IPosition`](IPosition.md).[`type`](IPosition.md#type)
