# Class: ProtocolsManagerClient

Defined in: [sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts#L11)

ProtocolsManagerClient

## See

IProtocolsManagerClient

## Extends

- `IRPCClient`

## Implements

- [`IProtocolsManagerClient`](../interfaces/IProtocolsManagerClient.md)

## Constructors

### Constructor

```ts
new ProtocolsManagerClient(params): ProtocolsManagerClient;
```

Defined in: [sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts#L14)

#### Parameters

##### params

###### chainInfo

[`ChainInfo`](ChainInfo.md)

###### rpcClient

`TRPCClient`

#### Returns

`ProtocolsManagerClient`

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

### getLendingPool()

```ts
getLendingPool(params): Promise<Maybe<ILendingPool>>;
```

Defined in: [sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts#L20)

#### Parameters

##### params

The pool id data

###### poolId

[`ILendingPoolIdData`](../type-aliases/ILendingPoolIdData.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`ILendingPool`](../interfaces/ILendingPool.md)\>\>

The lending pool

#### Method

getLendingPool

#### Description

Get the lending pool from the protocol

#### Implementation of

[`IProtocolsManagerClient`](../interfaces/IProtocolsManagerClient.md).[`getLendingPool`](../interfaces/IProtocolsManagerClient.md#getlendingpool)

***

### getLendingPoolInfo()

```ts
getLendingPoolInfo(params): Promise<Maybe<ILendingPoolInfo>>;
```

Defined in: [sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/implementation/ProtocolsManagerClient.ts#L24)

#### Parameters

##### params

The pool id data

###### poolId

[`ILendingPoolIdData`](../type-aliases/ILendingPoolIdData.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`ILendingPoolInfo`](../interfaces/ILendingPoolInfo.md)\>\>

The lending pool info

#### Method

getLendingPoolInfo

#### Description

Get the lending pool info from the protocol

#### Implementation of

[`IProtocolsManagerClient`](../interfaces/IProtocolsManagerClient.md).[`getLendingPoolInfo`](../interfaces/IProtocolsManagerClient.md#getlendingpoolinfo)
