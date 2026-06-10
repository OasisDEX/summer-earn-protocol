# Interface: ITokensManagerClient

Defined in: [sdk/sdk-client/src/interfaces/ITokensManagerClient.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ITokensManagerClient.ts#L10)

## Name

ITokensManagerClient

## Description

Interface for the TokensManager client implementation. Allows to retrieve information for
             a Token given its Chain, and its Address or symbol. The difference with the server side
             is that it stores the chain info internally and passes it as a parameter to the RPC calls

## See

ITokensManager

## Methods

### getTokenByAddress()

```ts
getTokenByAddress(params): Promise<Token>;
```

Defined in: [sdk/sdk-client/src/interfaces/ITokensManagerClient.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ITokensManagerClient.ts#L29)

#### Parameters

##### params

###### address

[`Address`](../classes/Address.md)

#### Returns

`Promise`\<[`Token`](../classes/Token.md)\>

The token with the given address

#### Method

getTokenByAddress

#### Description

Retrieves a token by its address

***

### getTokenByName()

```ts
getTokenByName(params): Promise<Token>;
```

Defined in: [sdk/sdk-client/src/interfaces/ITokensManagerClient.ts:39](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ITokensManagerClient.ts#L39)

#### Parameters

##### params

###### name

`string`

#### Returns

`Promise`\<[`Token`](../classes/Token.md)\>

The token with the given name

#### Method

getTokenByName

#### Description

Retrieves a token by its name

***

### getTokenBySymbol()

```ts
getTokenBySymbol(params): Promise<Token>;
```

Defined in: [sdk/sdk-client/src/interfaces/ITokensManagerClient.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ITokensManagerClient.ts#L19)

#### Parameters

##### params

###### symbol

`string`

#### Returns

`Promise`\<[`Token`](../classes/Token.md)\>

The token with the given symbol

#### Method

getTokenBySymbol

#### Description

Retrieves a token by its symbol
