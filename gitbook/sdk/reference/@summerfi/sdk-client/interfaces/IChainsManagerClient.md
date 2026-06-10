# Interface: IChainsManagerClient

Defined in: [sdk/sdk-client/src/interfaces/IChainsManager.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChainsManager.ts#L9)

IChainsManagerClient

## Description

Interface for the ChainsManager client implementation. Allows to retrieve information for
            a Chain given its ChainInfo. It also supports to lookup a chain by its name or chain ID

## Methods

### getChain()

```ts
getChain(params): Promise<Chain>;
```

Defined in: [sdk/sdk-client/src/interfaces/IChainsManager.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChainsManager.ts#L26)

#### Parameters

##### params

###### chainInfo

[`ChainInfo`](../classes/ChainInfo.md)

#### Returns

`Promise`\<[`Chain`](../classes/Chain.md)\>

The chain for the given chain info

#### Method

getChain

#### Description

Retrieves a chain by its chain info

***

### getChainById()

```ts
getChainById(params): Promise<Maybe<Chain>>;
```

Defined in: [sdk/sdk-client/src/interfaces/IChainsManager.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChainsManager.ts#L36)

#### Parameters

##### params

###### chainId

`number`

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`Chain`](../classes/Chain.md)\>\>

The network with the given chain ID

#### Method

getChainById

#### Description

Retrieves a network by its chain ID

***

### getSupportedChains()

```ts
getSupportedChains(): Promise<ChainInfo[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/IChainsManager.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IChainsManager.ts#L16)

#### Returns

`Promise`\<[`ChainInfo`](../classes/ChainInfo.md)[]\>

The list of supported chains

#### Method

getSupportedChains

#### Description

Retrieves the list of supported chains
