# Interface: IUserClient

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L18)

IUserClient

## Description

Represents a user and allows to access their positions and to create new orders

## Dev

This interface must be used to get positions for a user that will be used to create orders. To retrieve
     positions for portfolio please

## See

PortfolioManager

## Properties

### user

```ts
user: IUser;
```

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L19)

## Methods

### getPosition()

```ts
getPosition(params): Promise<Maybe<Position>>;
```

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L37)

#### Parameters

##### params

###### id

[`PositionId`](../classes/PositionId.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`Position`](../classes/Position.md)\>\>

#### Method

getPosition

#### Description

Retrieves a position of the user by its ID

***

### getPositionsByIds()

```ts
getPositionsByIds(params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L31)

#### Parameters

##### params

###### positionIds

[`PositionId`](../classes/PositionId.md)[]

#### Returns

`Promise`\<[`Position`](../classes/Position.md)[]\>

#### Method

getPositionsByIds

#### Description

Retrieves the list of positions of the user for the given IDs

***

### getPositionsByProtocol()

```ts
getPositionsByProtocol(params): Promise<Position[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L25)

#### Parameters

##### params

###### protocol

[`IProtocol`](IProtocol.md)

#### Returns

`Promise`\<[`Position`](../classes/Position.md)[]\>

#### Method

getPositionsByProtocol

#### Description

Retrieves the list of positions of the user for a given protocol

***

### newOrder()

```ts
newOrder(params): Promise<Maybe<Order>>;
```

Defined in: [sdk/sdk-client/src/interfaces/IUserClient.ts:47](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IUserClient.ts#L47)

#### Parameters

##### params

###### simulation

[`ISimulation`](ISimulation.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`Order`](Order.md)\>\>

The new order created for the user

#### Method

newOrder

#### Description

Creates a new order for the user based on the given simulation
