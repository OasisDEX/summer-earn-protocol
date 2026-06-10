# Class: UserClient

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L22)

UserClient

## See

IUserClient

## Extends

- `IRPCClient`

## Implements

- [`IUserClient`](../interfaces/IUserClient.md)

## Constructors

### Constructor

```ts
new UserClient(params): UserClient;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L26)

Constructor

#### Parameters

##### params

###### chainInfo

[`IChainInfo`](../interfaces/IChainInfo.md)

###### rpcClient

`TRPCClient`

###### wallet

[`IWallet`](../interfaces/IWallet.md)

#### Returns

`UserClient`

#### Overrides

```ts
IRPCClient.constructor
```

## Properties

### user

```ts
user: IUser;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L23)

#### Implementation of

[`IUserClient`](../interfaces/IUserClient.md).[`user`](../interfaces/IUserClient.md#user)

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

### getPosition()

```ts
getPosition(params): Promise<Maybe<Position>>;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:49](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L49)

#### Parameters

##### params

###### id

[`PositionId`](PositionId.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`Position`](Position.md)\>\>

#### Method

getPosition

#### Description

Retrieves a position of the user by its ID

#### Implementation of

[`IUserClient`](../interfaces/IUserClient.md).[`getPosition`](../interfaces/IUserClient.md#getposition)

***

### getPositionsByIds()

```ts
getPositionsByIds(_params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:43](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L43)

#### Parameters

##### \_params

###### positionIds

[`PositionId`](PositionId.md)[]

#### Returns

`Promise`\<[`Position`](Position.md)[]\>

#### Method

getPositionsByIds

#### Description

Retrieves the list of positions of the user for the given IDs

#### Implementation of

[`IUserClient`](../interfaces/IUserClient.md).[`getPositionsByIds`](../interfaces/IUserClient.md#getpositionsbyids)

***

### getPositionsByProtocol()

```ts
getPositionsByProtocol(_params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L37)

#### Parameters

##### \_params

###### protocol

[`IProtocol`](../interfaces/IProtocol.md)

#### Returns

`Promise`\<[`Position`](Position.md)[]\>

#### Method

getPositionsByProtocol

#### Description

Retrieves the list of positions of the user for a given protocol

#### Implementation of

[`IUserClient`](../interfaces/IUserClient.md).[`getPositionsByProtocol`](../interfaces/IUserClient.md#getpositionsbyprotocol)

***

### newOrder()

```ts
newOrder(params): Promise<Maybe<Order>>;
```

Defined in: [sdk/sdk-client/src/implementation/UserClient.ts:56](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/UserClient.ts#L56)

#### Parameters

##### params

###### positionsManager?

[`IPositionsManager`](../interfaces/IPositionsManager.md)

###### simulation

[`ISimulation`](../interfaces/ISimulation.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`Order`](../interfaces/Order.md)\>\>

The new order created for the user

#### Method

newOrder

#### Description

Creates a new order for the user based on the given simulation

#### Implementation of

[`IUserClient`](../interfaces/IUserClient.md).[`newOrder`](../interfaces/IUserClient.md#neworder)
