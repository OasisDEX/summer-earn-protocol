# Class: UsersManager

Defined in: [sdk/sdk-client/src/implementation/UsersManager.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UsersManager.ts#L8)

IUsersManager

## Description

Allows to retrieve a user by their wallet and network

## Extends

- `IRPCClient`

## Implements

- [`IUsersManager`](../interfaces/IUsersManager.md)

## Constructors

### Constructor

```ts
new UsersManager(params): UsersManager;
```

Defined in: [sdk/sdk-client/src/implementation/UsersManager.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UsersManager.ts#L9)

#### Parameters

##### params

###### rpcClient

`TRPCClient`

#### Returns

`UsersManager`

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

### getUserClient()

```ts
getUserClient(params): Promise<UserClient>;
```

Defined in: [sdk/sdk-client/src/implementation/UsersManager.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UsersManager.ts#L13)

#### Parameters

##### params

###### chainInfo

[`ChainInfo`](ChainInfo.md)

###### walletAddress

[`Address`](Address.md)

#### Returns

`Promise`\<[`UserClient`](UserClient.md)\>

The user for the given wallet and network

#### Method

getUserClient

#### Description

Retrieves a user by their wallet and network

#### Implementation of

[`IUsersManager`](../interfaces/IUsersManager.md).[`getUserClient`](../interfaces/IUsersManager.md#getuserclient)
