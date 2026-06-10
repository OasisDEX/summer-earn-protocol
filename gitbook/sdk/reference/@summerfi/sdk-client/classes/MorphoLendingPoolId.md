# Class: MorphoLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L18)

MorphoLendingPoolId

## See

IMorphoLendingPoolIdData

## Extends

- [`LendingPoolId`](LendingPoolId.md)

## Implements

- [`IMorphoLendingPoolId`](../interfaces/IMorphoLendingPoolId.md)
- [`IPrintable`](../interfaces/IPrintable.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L20)

SIGNATURE

#### Implementation of

[`IMorphoLendingPoolId`](../interfaces/IMorphoLendingPoolId.md).[`[___signature__]`](../interfaces/IMorphoLendingPoolId.md#___signature__-2)

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
IMorphoLendingPoolId.[___signature__]
```

#### Inherited from

```ts
LendingPoolId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol = __signature__;
```

Defined in: [sdk/sdk-common/src/common/implementation/PoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/PoolId.ts#L18)

SIGNATURE

#### Implementation of

```ts
IMorphoLendingPoolId.[___signature__]
```

#### Inherited from

```ts
LendingPoolId.[___signature__]
```

***

### marketId

```ts
readonly marketId: `0x${string}`;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L24)

The encoded market ID used to access the market parameters

#### Implementation of

[`IMorphoLendingPoolId`](../interfaces/IMorphoLendingPoolId.md).[`marketId`](../interfaces/IMorphoLendingPoolId.md#marketid)

***

### protocol

```ts
readonly protocol: IMorphoProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L23)

ATTRIBUTES

#### Implementation of

[`IMorphoLendingPoolId`](../interfaces/IMorphoLendingPoolId.md).[`protocol`](../interfaces/IMorphoLendingPoolId.md#protocol)

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

[`IMorphoLendingPoolId`](../interfaces/IMorphoLendingPoolId.md).[`type`](../interfaces/IMorphoLendingPoolId.md#type)

#### Inherited from

[`LendingPoolId`](LendingPoolId.md).[`type`](LendingPoolId.md#type)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L42)

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
static createFrom(params): MorphoLendingPoolId;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/implementation/MorphoLendingPoolId.ts#L27)

FACTORY

#### Parameters

##### params

`MorphoLendingPoolIdParameters`

#### Returns

`MorphoLendingPoolId`
