# Class: Chain

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L12)

## Name

Chain

## Description

Implementation of the IChain interface for the SDK Client

## Implements

- [`IChain`](../interfaces/IChain.md)

## Constructors

### Constructor

```ts
new Chain(params): Chain;
```

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L17)

#### Parameters

##### params

###### chainInfo

[`ChainInfo`](ChainInfo.md)

###### protocolsManager

[`ProtocolsManagerClient`](ProtocolsManagerClient.md)

###### tokensManager

[`TokensManagerClient`](TokensManagerClient.md)

#### Returns

`Chain`

## Properties

### chainInfo

```ts
readonly chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L13)

The information of the chain

#### Implementation of

[`IChain`](../interfaces/IChain.md).[`chainInfo`](../interfaces/IChain.md#chaininfo)

***

### protocols

```ts
readonly protocols: IProtocolsManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L15)

The protocols manager client for the chain, allows to retrieve protocols on the chain

#### Implementation of

[`IChain`](../interfaces/IChain.md).[`protocols`](../interfaces/IChain.md#protocols)

***

### tokens

```ts
readonly tokens: ITokensManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L14)

The tokens manager client for the chain, allows to retrieve tokens on the chain

#### Implementation of

[`IChain`](../interfaces/IChain.md).[`tokens`](../interfaces/IChain.md#tokens)

## Methods

### toString()

```ts
toString(): string;
```

Defined in: [sdk/sdk-client/src/implementation/Chain.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/Chain.ts#L27)

Returns a string representation of an object.

#### Returns

`string`
