# Interface: ILendingPool

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L22)

## Name

ILendingPool

## Description

Represents a lending pool for a single pair collateral/debt

A lending pool is a pool where users can deposit collateral and borrow debt against that collateral.
Typically the user will pay interest on the debt, and the collateral will be locked until the debt is repaid.

This interface is an abstraction of a lending pool and the specialization for each protocol happens at the IPool
level through the PoolId

## Extends

- [`IPool`](IPool.md).[`ILendingPoolData`](../type-aliases/ILendingPoolData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L24)

Signature to differentiate from similar interfaces

#### Inherited from

[`IPool`](IPool.md).[`[___signature__]`](IPool.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPool.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPool.ts#L20)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPool.[___signature__]
```

***

### collateralToken

```ts
readonly collateralToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L28)

Collateral token used to collateralized the pool

#### Overrides

```ts
ILendingPoolData.collateralToken
```

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L30)

Debt token, which can be borrowed from the pool

#### Overrides

```ts
ILendingPoolData.debtToken
```

***

### id

```ts
readonly id: ILendingPoolId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L26)

Pool ID of the lending pool

#### Overrides

[`IPool`](IPool.md).[`id`](IPool.md#id)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPool.ts#L33)

Type of the pool

#### Overrides

[`IPool`](IPool.md).[`type`](IPool.md#type)

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

[`IPool`](IPool.md).[`toString`](IPool.md#tostring)
