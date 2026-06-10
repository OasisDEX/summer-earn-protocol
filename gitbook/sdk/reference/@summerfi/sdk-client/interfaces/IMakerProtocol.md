# Interface: IMakerProtocol

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts#L16)

IMakerProtocol

## Description

Identifier of the Maker protocol

Typescript forces the interface to re-declare any properties that have different BUT compatible types.
This may be fixed eventually, there is a discussion on the topic here: https://github.com/microsoft/TypeScript/issues/16936

## Extends

- [`IProtocol`](IProtocol.md).`IMakerProtocolData`

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts#L18)

Interface signature used to differentiate it from similar interfaces

#### Inherited from

[`IProtocol`](IProtocol.md).[`[___signature__]`](IProtocol.md#___signature__)

***

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L18)

Signature used to differentiate it from similar interfaces

#### Inherited from

```ts
IProtocol.[___signature__]
```

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L22)

The chain information

#### Inherited from

[`IProtocol`](IProtocol.md).[`chainInfo`](IProtocol.md#chaininfo)

***

### name

```ts
readonly name: Maker;
```

Defined in: [sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/protocol-plugins/src/plugins/maker/interfaces/IMakerProtocol.ts#L21)

The name of the protocol

#### Overrides

[`IProtocol`](IProtocol.md).[`name`](IProtocol.md#name)

## Methods

### equals()

```ts
equals(protocol): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L31)

Compare if the passed protocol is equal to the current protocol

#### Parameters

##### protocol

[`IProtocol`](IProtocol.md)

The protocol to compare

#### Returns

`boolean`

true if the protocols are equal

Equality is determined by the name and chain information

#### Inherited from

[`IProtocol`](IProtocol.md).[`equals`](IProtocol.md#equals)
