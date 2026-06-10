# Class: AaveV3LendingPosition

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts#L19)

AaveV3Position

## See

IAaveV3LendingPosition

## Extends

- [`LendingPosition`](LendingPosition.md)

## Implements

- `IAaveV3LendingPosition`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts#L21)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPosition.[___signature__]
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
IAaveV3LendingPosition.[___signature__]
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`[___signature__]`](LendingPosition.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/Position.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/Position.ts#L18)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPosition.[___signature__]
```

#### Inherited from

[`Position`](Position.md).[`[___signature__]`](Position.md#___signature__)

***

### collateralAmount

```ts
readonly collateralAmount: ITokenAmount;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPosition.ts#L31)

Amount of collateral deposited in the pool

#### Implementation of

```ts
IAaveV3LendingPosition.collateralAmount
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
IAaveV3LendingPosition.debtAmount
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`debtAmount`](LendingPosition.md#debtamount)

***

### id

```ts
readonly id: IAaveV3LendingPositionId;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts#L25)

Unique identifier for the position inside the Summer.fi system

#### Implementation of

```ts
IAaveV3LendingPosition.id
```

#### Overrides

[`LendingPosition`](LendingPosition.md).[`id`](LendingPosition.md#id)

***

### pool

```ts
readonly pool: IAaveV3LendingPool;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts#L24)

ATTRIBUTES

#### Implementation of

```ts
IAaveV3LendingPosition.pool
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
IAaveV3LendingPosition.subtype
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
IAaveV3LendingPosition.type
```

#### Inherited from

[`LendingPosition`](LendingPosition.md).[`type`](LendingPosition.md#type)

## Methods

### createFrom()

```ts
static createFrom(params): AaveV3LendingPosition;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPosition.ts#L28)

FACTORY

#### Parameters

##### params

`AaveV3LendingPositionParameters`

#### Returns

`AaveV3LendingPosition`
