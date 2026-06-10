# Interface: ILendingPoolInfo

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L25)

## Name

ILendingPoolInfo

## Description

Represents the extended information for a lending pool of a single pair collateral/debt

This extended information includes extra info for the collateral and debt like the liquidation threshold, liquidation penalty, total amount
borroed, etc...

The intention of this interface is to standardize the information that the protocol plugins should provide for the lending pools and it is
not intended to be specialized by the protocol plugins. The reason for this is that the plugins already have this information and the SDK
tries to abstract this information to provide a common interface for all the protocols on the client side.

## Extends

- [`IPoolInfo`](IPoolInfo.md).[`ILendingPoolInfoData`](../type-aliases/ILendingPoolInfoData.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L27)

Signature to differentiate from similar interfaces

#### Inherited from

[`IPoolInfo`](IPoolInfo.md).[`[___signature__]`](IPoolInfo.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolInfo.ts#L18)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
IPoolInfo.[___signature__]
```

***

### collateral

```ts
readonly collateral: ICollateralInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L31)

The collateral information of the pool

#### Overrides

```ts
ILendingPoolInfoData.collateral
```

***

### debt

```ts
readonly debt: IDebtInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L33)

The debt information of the pool

#### Overrides

```ts
ILendingPoolInfoData.debt
```

***

### id

```ts
readonly id: ILendingPoolId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L29)

Pool ID of the lending pool

#### Overrides

[`IPoolInfo`](IPoolInfo.md).[`id`](IPoolInfo.md#id)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolInfo.ts#L36)

Type of the pool

#### Overrides

[`IPoolInfo`](IPoolInfo.md).[`type`](IPoolInfo.md#type)
