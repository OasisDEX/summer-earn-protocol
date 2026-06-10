# Class: AaveV3LendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L19)

AaveV3LendingPoolId

## See

IAaveV3LendingPoolId

## Extends

- [`LendingPoolId`](LendingPoolId.md)

## Implements

- [`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L21)

SIGNATURE

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`[___signature__]`](../interfaces/IAaveV3LendingPoolId.md#___signature__-2)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`[___signature__]`](LendingPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPoolId.[___signature__]
```

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`[___signature__]`](LendingPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IAaveV3LendingPoolId.[___signature__]
```

#### Inherited from

[`MakerLendingPoolId`](MakerLendingPoolId.md).[`[___signature__]`](MakerLendingPoolId.md#___signature__-2)

***

### collateralToken

```ts
readonly collateralToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L26)

The token used to collateralized the position

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`collateralToken`](../interfaces/IAaveV3LendingPoolId.md#collateraltoken)

***

### debtToken

```ts
readonly debtToken: ITokenStanalone;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L27)

The token used to borrow funds

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`debtToken`](../interfaces/IAaveV3LendingPoolId.md#debttoken)

***

### emodeType

```ts
readonly emodeType: EmodeType;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L25)

The pool's efficiency mode

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`emodeType`](../interfaces/IAaveV3LendingPoolId.md#emodetype)

***

### protocol

```ts
readonly protocol: IAaveV3Protocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L24)

ATTRIBUTES

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`protocol`](../interfaces/IAaveV3LendingPoolId.md#protocol)

#### Overrides

[`LendingPoolId`](LendingPoolId.md).[`protocol`](LendingPoolId.md#protocol)

***

### type

```ts
readonly type: Lending = PoolType.Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/implementation/LendingPoolId.ts#L21)

ATTRIBUTES

#### Implementation of

[`IAaveV3LendingPoolId`](../interfaces/IAaveV3LendingPoolId.md).[`type`](../interfaces/IAaveV3LendingPoolId.md#type)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`type`](LendingPoolId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:47](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L47)

#### Returns

`string`

#### See

IPrintable.toString

#### Implementation of

[`IPrintable`](../interfaces/IPrintable.md).[`toString`](../interfaces/IPrintable.md#tostring)

#### Overrides

[`LendingPoolId`](LendingPoolId.md).[`toString`](LendingPoolId.md#tostring)

***

### createFrom()

```ts
static createFrom(params): AaveV3LendingPoolId;
```

Defined in: [sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/aave-v3/implementation/AaveV3LendingPoolId.ts#L30)

FACTORY

#### Parameters

##### params

`AaveV3LendingPoolIdParameters`

#### Returns

`AaveV3LendingPoolId`
