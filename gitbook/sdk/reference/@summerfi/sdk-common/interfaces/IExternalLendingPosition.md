# Interface: IExternalLendingPosition

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts#L18)

IExternalLendingPosition

## Description

Lending position existing in another service

## Extends

- [`ILendingPosition`](ILendingPosition.md).[`IPrintable`](IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts#L20)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`[___signature__]`](ILendingPosition.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L20)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPosition.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPosition.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPosition.ts#L17)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPosition.[___signature__]
```

***

### collateralAmount

```ts
readonly collateralAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L28)

Amount of collateral deposited in the pool

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`collateralAmount`](ILendingPosition.md#collateralamount)

***

### debtAmount

```ts
readonly debtAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L26)

Amount of debt borrowed from the pool

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`debtAmount`](ILendingPosition.md#debtamount)

***

### id

```ts
readonly id: IExternalLendingPositionId;
```

Defined in: [sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/orders/importing/interfaces/IExternalLendingPosition.ts#L22)

External position ID

#### Overrides

[`ILendingPosition`](ILendingPosition.md).[`id`](ILendingPosition.md#id)

***

### pool

```ts
readonly pool: ILendingPool;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L30)

Pool where the position is

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`pool`](ILendingPosition.md#pool)

***

### subtype

```ts
readonly subtype: LendingPositionType;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L22)

Subtype of the position in the Summer.fi system

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`subtype`](ILendingPosition.md#subtype)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPosition.ts#L33)

Type of the position in the Summer.fi system

#### Inherited from

[`ILendingPosition`](ILendingPosition.md).[`type`](ILendingPosition.md#type)

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
