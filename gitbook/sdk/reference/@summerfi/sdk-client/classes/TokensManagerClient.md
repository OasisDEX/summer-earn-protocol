# Class: TokensManagerClient

Defined in: [sdk/sdk-client/src/implementation/TokensManagerClient.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/TokensManagerClient.ts#L10)

## Name

TokensManagerClient

## Description

Implementation of the ITokensManager interface for the SDK Client

## Extends

- `IRPCClient`

## Implements

- [`ITokensManagerClient`](../interfaces/ITokensManagerClient.md)

## Constructors

### Constructor

```ts
new TokensManagerClient(params): TokensManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/TokensManagerClient.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/TokensManagerClient.ts#L13)

#### Parameters

##### params

###### chainInfo

[`ChainInfo`](ChainInfo.md)

###### rpcClient

`TRPCClient`

#### Returns

`TokensManagerClient`

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

### getTokenByAddress()

```ts
getTokenByAddress(params): Promise<ITokenStanalone>;
```

Defined in: [sdk/sdk-client/src/implementation/TokensManagerClient.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/TokensManagerClient.ts#L28)

#### Parameters

##### params

###### address

[`Address`](Address.md)

#### Returns

`Promise`\<[`ITokenStanalone`](../interfaces/ITokenStanalone.md)\>

#### See

ITokensManagerClient.getTokenByAddress

#### Implementation of

[`ITokensManagerClient`](../interfaces/ITokensManagerClient.md).[`getTokenByAddress`](../interfaces/ITokensManagerClient.md#gettokenbyaddress)

***

### getTokenByName()

```ts
getTokenByName(_params): Promise<ITokenStanalone>;
```

Defined in: [sdk/sdk-client/src/implementation/TokensManagerClient.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/TokensManagerClient.ts#L36)

#### Parameters

##### \_params

###### name

`string`

#### Returns

`Promise`\<[`ITokenStanalone`](../interfaces/ITokenStanalone.md)\>

#### See

ITokensManagerClient.getTokenByName

#### Implementation of

[`ITokensManagerClient`](../interfaces/ITokensManagerClient.md).[`getTokenByName`](../interfaces/ITokensManagerClient.md#gettokenbyname)

***

### getTokenBySymbol()

```ts
getTokenBySymbol(params): Promise<ITokenStanalone>;
```

Defined in: [sdk/sdk-client/src/implementation/TokensManagerClient.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/TokensManagerClient.ts#L20)

#### Parameters

##### params

###### symbol

`string`

#### Returns

`Promise`\<[`ITokenStanalone`](../interfaces/ITokenStanalone.md)\>

#### See

ITokensManagerClient.getTokenBySymbol

#### Implementation of

[`ITokensManagerClient`](../interfaces/ITokensManagerClient.md).[`getTokenBySymbol`](../interfaces/ITokensManagerClient.md#gettokenbysymbol)
