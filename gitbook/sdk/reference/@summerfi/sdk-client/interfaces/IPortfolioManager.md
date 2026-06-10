# Interface: IPortfolioManager

Defined in: [sdk/sdk-client/src/interfaces/IPortfolioManager.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IPortfolioManager.ts#L8)

IPortfolioManager

## Description

Allows to retrieve a wallet's positions by their wallet and network. This is meant to be used in isolation
             without having to retrieve a User or a Network

## Methods

### getPositions()

```ts
getPositions(params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/IPortfolioManager.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IPortfolioManager.ts#L19)

#### Parameters

##### params

###### networks

[`ChainInfo`](../classes/ChainInfo.md)[]

###### wallet

[`Wallet`](../classes/Wallet.md)

#### Returns

`Promise`\<[`Position`](../classes/Position.md)[]\>

The list of positions for the given wallet and networks

#### Method

getPositions

#### Description

Retrieves all positions of the given wallet for the given networks. The positions can be filtered by
             their IDs
