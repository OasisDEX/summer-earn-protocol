# Interface: IChain

Defined in: [sdk/sdk-client/src/interfaces/IChain.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChain.ts#L9)

IChain

## Description

Represents a blockchain network and allows to access the tokens and protocols of the chain

## Properties

### chainInfo

```ts
chainInfo: IChainInfo;
```

Defined in: [sdk/sdk-client/src/interfaces/IChain.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChain.ts#L11)

The information of the chain

***

### protocols

```ts
protocols: IProtocolsManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/IChain.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChain.ts#L15)

The protocols manager client for the chain, allows to retrieve protocols on the chain

***

### tokens

```ts
tokens: ITokensManagerClient;
```

Defined in: [sdk/sdk-client/src/interfaces/IChain.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChain.ts#L13)

The tokens manager client for the chain, allows to retrieve tokens on the chain
