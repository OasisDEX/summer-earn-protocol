# Interface: IProtocolsManagerClient

Defined in: [sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts#L8)

IProtocolsManagerClient

## Description

Interface of the ProtocolsManager for the SDK Client. Allows to retrieve information for a Protocol

## See

IProtocolsManager

## Methods

### getLendingPool()

```ts
getLendingPool(params): Promise<Maybe<ILendingPool>>;
```

Defined in: [sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts#L15)

#### Parameters

##### params

The pool id data

###### poolId

[`ILendingPoolIdData`](../type-aliases/ILendingPoolIdData.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`ILendingPool`](ILendingPool.md)\>\>

The lending pool

#### Method

getLendingPool

#### Description

Get the lending pool from the protocol

***

### getLendingPoolInfo()

```ts
getLendingPoolInfo(params): Promise<Maybe<ILendingPoolInfo>>;
```

Defined in: [sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/IProtocolsManagerClient.ts#L23)

#### Parameters

##### params

The pool id data

###### poolId

[`ILendingPoolIdData`](../type-aliases/ILendingPoolIdData.md)

#### Returns

`Promise`\<[`Maybe`](../type-aliases/Maybe.md)\<[`ILendingPoolInfo`](ILendingPoolInfo.md)\>\>

The lending pool info

#### Method

getLendingPoolInfo

#### Description

Get the lending pool info from the protocol
