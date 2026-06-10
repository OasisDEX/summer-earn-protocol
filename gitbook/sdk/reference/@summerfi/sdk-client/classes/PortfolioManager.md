# Class: PortfolioManager

Defined in: [sdk/sdk-client/src/implementation/PortfolioManager.ts:6](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/PortfolioManager.ts#L6)

IPortfolioManager

## Description

Allows to retrieve a wallet's positions by their wallet and network. This is meant to be used in isolation
             without having to retrieve a User or a Network

## Extends

- `IRPCClient`

## Implements

- [`IPortfolioManager`](../interfaces/IPortfolioManager.md)

## Constructors

### Constructor

```ts
new PortfolioManager(params): PortfolioManager;
```

Defined in: [sdk/sdk-client/src/implementation/PortfolioManager.ts:7](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/PortfolioManager.ts#L7)

#### Parameters

##### params

###### rpcClient

`TRPCClient`

#### Returns

`PortfolioManager`

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

### getPositions()

```ts
getPositions(_params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/implementation/PortfolioManager.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/PortfolioManager.ts#L12)

#### Parameters

##### \_params

###### networks

[`ChainInfo`](ChainInfo.md)[]

###### wallet

[`Wallet`](Wallet.md)

#### Returns

`Promise`\<[`Position`](Position.md)[]\>

The list of positions for the given wallet and networks

#### Method

getPositions

#### Description

Retrieves all positions of the given wallet for the given networks. The positions can be filtered by
             their IDs

#### Implementation of

[`IPortfolioManager`](../interfaces/IPortfolioManager.md).[`getPositions`](../interfaces/IPortfolioManager.md#getpositions)
