# Interface: IMorphoLendingPoolId

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts#L18)

IMorphoLendingPoolId

## Description

Identifier of a lending pool in the Morpho protocol

Typescript forces the interface to re-declare any properties that have different BUT compatible types.
This may be fixed eventually, there is a discussion on the topic here: https://github.com/microsoft/TypeScript/issues/16936

## Extends

- `IMorphoLendingPoolIdData`.[`ILendingPoolId`](ILendingPoolId.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts#L20)

Signature used to differentiate it from similar interfaces

#### Inherited from

[`ILendingPoolId`](ILendingPoolId.md).[`[___signature__]`](ILendingPoolId.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L23)

Signature to differentiate it from other interfaces

#### Inherited from

```ts
ILendingPoolId.[___signature__]
```

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IPoolId.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IPoolId.ts#L19)

Signature to differentiate from similar interfaces

#### Inherited from

```ts
ILendingPoolId.[___signature__]
```

***

### marketId

```ts
readonly marketId: `0x${string}`;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts#L24)

The encoded market ID used to access the market parameters

#### Overrides

```ts
IMorphoLendingPoolIdData.marketId
```

***

### protocol

```ts
readonly protocol: IMorphoProtocol;
```

Defined in: [sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/morphoblue/interfaces/IMorphoLendingPoolId.ts#L22)

The protocol to which the pool belongs

#### Overrides

[`ILendingPoolId`](ILendingPoolId.md).[`protocol`](ILendingPoolId.md#protocol)

***

### type

```ts
readonly type: Lending;
```

Defined in: [sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/lending-protocols/interfaces/ILendingPoolId.ts#L36)

Pool type

#### Inherited from

[`ILendingPoolId`](ILendingPoolId.md).[`type`](ILendingPoolId.md#type)
