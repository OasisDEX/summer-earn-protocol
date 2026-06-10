# Abstract Class: LendingPoolInfo

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L26)

LendingPoolInfo

## See

ILendingPoolInfo

The class is abstract to force each protocol to implement it's own version of the LendingPoolInfo by
customizing the PoolId

## Extends

- `PoolInfo`

## Implements

- [`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Constructors

### Constructor

```ts
protected new LendingPoolInfo(params): LendingPoolInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L37)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`LendingPoolInfoParameters`](../type-aliases/LendingPoolInfoParameters.md)

#### Returns

`LendingPoolInfo`

#### Overrides

```ts
PoolInfo.constructor
```

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L28)

SIGNATURE

#### Implementation of

[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md).[`[___signature__]`](../interfaces/ILendingPoolInfo.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolInfo.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolInfo.ts#L18)

SIGNATURE

#### Implementation of

```ts
ILendingPoolInfo.[___signature__]
```

#### Inherited from

```ts
PoolInfo.[___signature__]
```

***

### collateral

```ts
readonly collateral: ICollateralInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L32)

The collateral information of the pool

#### Implementation of

[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md).[`collateral`](../interfaces/ILendingPoolInfo.md#collateral)

***

### debt

```ts
readonly debt: IDebtInfo;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L33)

The debt information of the pool

#### Implementation of

[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md).[`debt`](../interfaces/ILendingPoolInfo.md#debt)

***

### id

```ts
abstract readonly id: ILendingPoolId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L31)

ATTRIBUTES

#### Implementation of

[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md).[`id`](../interfaces/ILendingPoolInfo.md#id)

#### Overrides

```ts
PoolInfo.id
```

***

### type

```ts
readonly type: Lending = PoolType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L34)

ATTRIBUTES

#### Implementation of

[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md).[`type`](../interfaces/ILendingPoolInfo.md#type)

#### Overrides

```ts
PoolInfo.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts:47](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolInfo.ts#L47)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

#### Overrides

```ts
PoolInfo.toString
```
