# Abstract Class: LendingPool

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L22)

LendingPool

## See

ILendingPool

The class is abstract to force each protocol to implement it's own version of the LendingPool by
customizing the PoolId

## Extends

- `Pool`

## Implements

- [`ILendingPool`](../interfaces/ILendingPool.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Constructors

### Constructor

```ts
protected new LendingPool(params): LendingPool;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L33)

SEALED CONSTRUCTOR

#### Parameters

##### params

[`LendingPoolParameters`](../type-aliases/LendingPoolParameters.md)

#### Returns

`LendingPool`

#### Overrides

```ts
Pool.constructor
```

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L24)

SIGNATURE

#### Implementation of

[`ILendingPool`](../interfaces/ILendingPool.md).[`[___signature__]`](../interfaces/ILendingPool.md#___signature__-1)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Pool.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Pool.ts#L18)

SIGNATURE

#### Implementation of

```ts
ILendingPool.[___signature__]
```

#### Inherited from

```ts
Pool.[___signature__]
```

***

### collateralToken

```ts
readonly collateralToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L28)

Collateral token used to collateralized the pool

#### Implementation of

[`ILendingPool`](../interfaces/ILendingPool.md).[`collateralToken`](../interfaces/ILendingPool.md#collateraltoken)

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L29)

Debt token, which can be borrowed from the pool

#### Implementation of

[`ILendingPool`](../interfaces/ILendingPool.md).[`debtToken`](../interfaces/ILendingPool.md#debttoken)

***

### id

```ts
abstract readonly id: ILendingPoolId;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L27)

ATTRIBUTES

#### Implementation of

[`ILendingPool`](../interfaces/ILendingPool.md).[`id`](../interfaces/ILendingPool.md#id)

#### Overrides

```ts
Pool.id
```

***

### type

```ts
readonly type: Lending = PoolType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L30)

ATTRIBUTES

#### Implementation of

[`ILendingPool`](../interfaces/ILendingPool.md).[`type`](../interfaces/ILendingPool.md#type)

#### Overrides

```ts
Pool.type
```

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPool.ts#L43)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

#### Overrides

```ts
Pool.toString
```
