# Class: ChainsManagerClient

Defined in: [sdk/sdk-client/src/implementation/ChainsManager.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ChainsManager.ts#L19)

## Name

ChainsManagerClient

## Description

Implementation of the IChainsManager interface for the SDK Client

## Extends

- `IRPCClient`

## Implements

- [`IChainsManagerClient`](../interfaces/IChainsManagerClient.md)

## Constructors

### Constructor

```ts
new ChainsManagerClient(params): ChainsManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/ChainsManager.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ChainsManager.ts#L20)

#### Parameters

##### params

###### rpcClient

`TRPCClient`

#### Returns

`ChainsManagerClient`

#### Overrides

```ts
IRPCClient.constructor
```

## Accessors

### rpcClient

#### Get Signature

```ts
get protected rpcClient(): TRPCClient;
```

Defined in: [sdk/sdk-client/src/interfaces/IRPCClient.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IRPCClient.ts#L10)

##### Returns

`TRPCClient`

#### Inherited from

```ts
IRPCClient.rpcClient
```

## Methods

### getChain()

```ts
getChain(params): Promise<Chain>;
```

Defined in: [sdk/sdk-client/src/implementation/ChainsManager.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ChainsManager.ts#L30)

#### Parameters

##### params

###### chainInfo

[`IChainInfoData`](../type-aliases/IChainInfoData.md)

#### Returns

`Promise`\<[`Chain`](Chain.md)\>

The chain for the given chain info

#### Method

getChain

#### Description

Retrieves a chain by its chain info

#### Implementation of

[`IChainsManagerClient`](../interfaces/IChainsManagerClient.md).[`getChain`](../interfaces/IChainsManagerClient.md#getchain)

***

### getChainById()

```ts
getChainById(params): Promise<Chain>;
```

Defined in: [sdk/sdk-client/src/implementation/ChainsManager.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ChainsManager.ts#L43)

#### Parameters

##### params

###### chainId

`number`

#### Returns

`Promise`\<[`Chain`](Chain.md)\>

The network with the given chain ID

#### Method

getChainById

#### Description

Retrieves a network by its chain ID

#### Implementation of

[`IChainsManagerClient`](../interfaces/IChainsManagerClient.md).[`getChainById`](../interfaces/IChainsManagerClient.md#getchainbyid)

***

### getSupportedChains()

```ts
getSupportedChains(): Promise<ChainInfo[]>;
```

Defined in: [sdk/sdk-client/src/implementation/ChainsManager.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ChainsManager.ts#L24)

#### Returns

`Promise`\<[`ChainInfo`](ChainInfo.md)[]\>

The list of supported chains

#### Method

getSupportedChains

#### Description

Retrieves the list of supported chains

#### Implementation of

[`IChainsManagerClient`](../interfaces/IChainsManagerClient.md).[`getSupportedChains`](../interfaces/IChainsManagerClient.md#getsupportedchains)
