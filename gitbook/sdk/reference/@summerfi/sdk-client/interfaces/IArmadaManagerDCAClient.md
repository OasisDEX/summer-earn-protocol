# Interface: IArmadaManagerDCAClient

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L21)

## Name

IArmadaManagerDCAClient

## Description

Client interface for Armada DCA order management

## Methods

### cancelBuyOrder()

```ts
cancelBuyOrder(params): Promise<IArmadaDcaOrder>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:124](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L124)

#### Parameters

##### params

###### orderId

`string`

###### signature

`` `0x${string}` ``

###### signedMessage

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)\>

***

### cancelStrategyTx()

```ts
cancelStrategyTx(params): Promise<CancelDcaStrategyTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:50](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L50)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### strategyId

`string`

#### Returns

`Promise`\<[`CancelDcaStrategyTransactionInfo`](../type-aliases/CancelDcaStrategyTransactionInfo.md)\>

***

### createAndSaveBuyOrder()

```ts
createAndSaveBuyOrder(params): Promise<IArmadaDcaOrder>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:63](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L63)

#### Parameters

##### params

###### amount

[`ITokenAmount`](ITokenAmount.md)

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### deadlineUnixTimestamp?

`number`

Unix timestamp after which the order stops executing (optional)

###### firstExecutionUnixTimestamp

`number`

Unix timestamp of the first scheduled execution

###### fromVault

`` `0x${string}` ``

###### id

`string`

###### intervalSeconds

`number`

###### maxTrades

`number`

Maximum number of trades to execute before the order completes

###### neverBuyAbove?

`string`

Price ceiling — skip execution if the fromVault token price is above this value (optional)

###### neverSellBelow?

`string`

Price floor — skip execution if the toVault token price is below this value (optional)

###### orderId

`string`

###### signTypedData

(`params`) => `Promise`\<`` `0x${string}` ``\>

###### slippagePercentage

`string`

Slippage as a percentage (e.g. "0.5" for 0.5%)

###### toVault

`` `0x${string}` ``

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)\>

***

### createStrategyTx()

```ts
createStrategyTx(params): Promise<CreateDcaStrategyTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L22)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

#### Returns

`Promise`\<[`CreateDcaStrategyTransactionInfo`](../type-aliases/CreateDcaStrategyTransactionInfo.md)\>

***

### editBuyOrder()

```ts
editBuyOrder(params): Promise<IArmadaDcaOrder>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:87](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L87)

#### Parameters

##### params

###### amount

[`ITokenAmount`](ITokenAmount.md)

###### bearerToken

`string`

EARN JWT bearer token for authentication

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### deadlineUnixTimestamp?

`number`

Unix timestamp after which the order stops executing (optional)

###### firstExecutionUnixTimestamp

`number`

Unix timestamp of the first scheduled execution

###### fromVault

`` `0x${string}` ``

###### id

`string`

###### intervalSeconds

`number`

###### maxTrades

`number`

Maximum number of trades to execute before the order completes

###### neverBuyAbove?

`string`

Price ceiling — skip execution if the fromVault token price is above this value (optional)

###### neverSellBelow?

`string`

Price floor — skip execution if the toVault token price is below this value (optional)

###### orderId

`string`

###### signTypedData

(`params`) => `Promise`\<`` `0x${string}` ``\>

###### slippagePercentage

`string`

Slippage as a percentage (e.g. "0.5" for 0.5%)

###### toVault

`` `0x${string}` ``

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)\>

***

### editStrategyTx()

```ts
editStrategyTx(params): Promise<EditDcaStrategyTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L29)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`EditDcaStrategyTransactionInfo`](../type-aliases/EditDcaStrategyTransactionInfo.md)\>

***

### executeDCATx()

```ts
executeDCATx(params): Promise<ExecuteDcaTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:55](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L55)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`ExecuteDcaTransactionInfo`](../type-aliases/ExecuteDcaTransactionInfo.md)\>

***

### getBuyOrder()

```ts
getBuyOrder(params): Promise<IArmadaDcaOrder | undefined>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:113](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L113)

#### Parameters

##### params

###### orderId

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md) \| `undefined`\>

***

### getBuyOrders()

```ts
getBuyOrders(params): Promise<IArmadaDcaOrder[]>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:118](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L118)

#### Parameters

##### params

###### chainId?

[`ChainId`](../type-aliases/ChainId.md)

###### status?

[`ArmadaDcaOrderStatusEnum`](../enumerations/ArmadaDcaOrderStatusEnum.md)

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)[]\>

***

### pauseBuyOrder()

```ts
pauseBuyOrder(params): Promise<IArmadaDcaOrder>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:131](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L131)

#### Parameters

##### params

###### orderId

`string`

###### signature

`` `0x${string}` ``

###### signedMessage

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)\>

***

### pauseStrategyTx()

```ts
pauseStrategyTx(params): Promise<PauseDcaStrategyTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:37](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L37)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### strategyId

`string`

#### Returns

`Promise`\<[`PauseDcaStrategyTransactionInfo`](../type-aliases/PauseDcaStrategyTransactionInfo.md)\>

***

### resumeBuyOrder()

```ts
resumeBuyOrder(params): Promise<IArmadaDcaOrder>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:138](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L138)

#### Parameters

##### params

###### orderId

`string`

###### signature

`` `0x${string}` ``

###### signedMessage

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](IArmadaDcaOrder.md)\>

***

### resumeStrategyTx()

```ts
resumeStrategyTx(params): Promise<ResumeDcaStrategyTransactionInfo>;
```

Defined in: [sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts:42](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client/src/interfaces/ArmadaManager/IArmadaManagerDCAClient.ts#L42)

#### Parameters

##### params

###### chainId

[`ChainId`](../type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`ResumeDcaStrategyTransactionInfo`](../type-aliases/ResumeDcaStrategyTransactionInfo.md)\>
