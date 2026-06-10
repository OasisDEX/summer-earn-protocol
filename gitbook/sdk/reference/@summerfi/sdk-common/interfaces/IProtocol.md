# Interface: IProtocol

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L16)

IProtocol

## Description

Information relative to a protocol

This interface is used to add all the methods that the interface supports

## Extends

- [`IProtocolData`](../type-aliases/IProtocolData.md)

## Extended by

- [`IArmadaProtocol`](IArmadaProtocol.md)

## Properties

### \[\_\_\_signature\_\_\]

```ts
readonly [___signature__]: symbol;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L18)

Signature used to differentiate it from similar interfaces

***

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L22)

The chain information

#### Overrides

```ts
IProtocolData.chainInfo
```

***

### name

```ts
readonly name: ProtocolName;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L20)

The name of the protocol

#### Overrides

```ts
IProtocolData.name
```

## Methods

### equals()

```ts
equals(protocol): boolean;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IProtocol.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IProtocol.ts#L31)

Compare if the passed protocol is equal to the current protocol

#### Parameters

##### protocol

`IProtocol`

The protocol to compare

#### Returns

`boolean`

true if the protocols are equal

Equality is determined by the name and chain information
