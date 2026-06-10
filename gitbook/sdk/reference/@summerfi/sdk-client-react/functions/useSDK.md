# Function: useSDK()

```ts
function useSDK(params): object;
```

Defined in: [sdk/sdk-client-react/src/hooks/useSDK.ts:116](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-client-react/src/hooks/useSDK.ts#L116)

## Parameters

### params

`UseSdk`

## Returns

`object`

### authorizeStakingRewardsCallerV2()

```ts
authorizeStakingRewardsCallerV2: (__namedParameters) => Promise<[ClaimTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### authorizedCallerAddress

`` `0x${string}` ``

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### isAuthorized

`boolean`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<\[[`ClaimTransactionInfo`](../../sdk-common/type-aliases/ClaimTransactionInfo.md)\]\>

### cancelBuyOrder()

```ts
cancelBuyOrder: (__namedParameters) => Promise<IArmadaDcaOrder>;
```

#### Parameters

##### \_\_namedParameters

###### orderId

`string`

###### signature

`` `0x${string}` ``

###### signedMessage

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)\>

### cancelStrategyTx()

```ts
cancelStrategyTx: (__namedParameters) => Promise<CancelDcaStrategyTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### strategyId

`string`

#### Returns

`Promise`\<[`CancelDcaStrategyTransactionInfo`](../../sdk-common/type-aliases/CancelDcaStrategyTransactionInfo.md)\>

### createAndSaveBuyOrder()

```ts
createAndSaveBuyOrder: (__namedParameters) => Promise<IArmadaDcaOrder>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

Full token amount (e.g. "1.5" for 1.5 USDC, not raw units)

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### deadlineUnixTimestamp?

`number`

Unix timestamp after which the order stops executing (optional)

###### firstExecutionUnixTimestamp

`number`

Unix timestamp of the first scheduled execution

###### fromVaultAddress

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

###### signTypedData

(`params`) => `Promise`\<`` `0x${string}` ``\>

###### slippagePercentage

`string`

Slippage as a percentage (e.g. "0.5" for 0.5%)

###### toVaultAddress

`` `0x${string}` ``

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)\>

### createStrategyTx()

```ts
createStrategyTx: (__namedParameters) => Promise<CreateDcaStrategyTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

#### Returns

`Promise`\<[`CreateDcaStrategyTransactionInfo`](../../sdk-common/type-aliases/CreateDcaStrategyTransactionInfo.md)\>

### editStrategyTx()

```ts
editStrategyTx: (__namedParameters) => Promise<EditDcaStrategyTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`EditDcaStrategyTransactionInfo`](../../sdk-common/type-aliases/EditDcaStrategyTransactionInfo.md)\>

### executeDCATx()

```ts
executeDCATx: (__namedParameters) => Promise<ExecuteDcaTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`ExecuteDcaTransactionInfo`](../../sdk-common/type-aliases/ExecuteDcaTransactionInfo.md)\>

### getAddresses()

```ts
getAddresses: (__namedParameters) => Promise<Record<"admiralsQuarters", `0x${string}`>>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

#### Returns

`Promise`\<`Record`\<`"admiralsQuarters"`, `` `0x${string}` ``\>\>

### getAggregatedClaimsForChainTx()

```ts
getAggregatedClaimsForChainTx: (__namedParameters) => Promise<
  | [ClaimTransactionInfo]
| undefined>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### includeMerkl?

`boolean`

###### includeStakingV2?

`boolean` = `true`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| \[[`ClaimTransactionInfo`](../../sdk-common/type-aliases/ClaimTransactionInfo.md)\]
  \| `undefined`\>

### getAggregatedRewards()

```ts
getAggregatedRewards: (__namedParameters) => Promise<{
  distribution: bigint;
  perChain: Record<number, bigint>;
  stakingV2: bigint;
  total: bigint;
  vaultUsage: bigint;
  vaultUsagePerChain: Record<number, bigint>;
  voteDelegation: bigint;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

`number`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<\{
  `distribution`: `bigint`;
  `perChain`: `Record`\<`number`, `bigint`\>;
  `stakingV2`: `bigint`;
  `total`: `bigint`;
  `vaultUsage`: `bigint`;
  `vaultUsagePerChain`: `Record`\<`number`, `bigint`\>;
  `voteDelegation`: `bigint`;
\}\>

### getAggregatedRewardsIncludingMerkl()

```ts
getAggregatedRewardsIncludingMerkl: (__namedParameters) => Promise<{
  distribution: bigint;
  perChain: Record<number, bigint>;
  stakingV2: bigint;
  total: bigint;
  vaultUsage: bigint;
  vaultUsagePerChain: Record<number, bigint>;
  voteDelegation: bigint;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

`number`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<\{
  `distribution`: `bigint`;
  `perChain`: `Record`\<`number`, `bigint`\>;
  `stakingV2`: `bigint`;
  `total`: `bigint`;
  `vaultUsage`: `bigint`;
  `vaultUsagePerChain`: `Record`\<`number`, `bigint`\>;
  `voteDelegation`: `bigint`;
\}\>

### getAllRoles()

```ts
getAllRoles: (__namedParameters) => Promise<RolesResponse>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### first?

`number`

###### name?

`string`

###### owner?

`` `0x${string}` ``

###### skip?

`number`

###### targetContract?

`` `0x${string}` ``

#### Returns

`Promise`\<[`RolesResponse`](../../sdk-common/type-aliases/RolesResponse.md)\>

### getAuthorizeAsMerklRewardsOperatorTx()

```ts
getAuthorizeAsMerklRewardsOperatorTx: (__namedParameters) => Promise<[ToggleAQasMerklRewardsOperatorTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`ChainInfo`](../../sdk-common/classes/ChainInfo.md)

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<\[[`ToggleAQasMerklRewardsOperatorTransactionInfo`](../../sdk-common/type-aliases/ToggleAQasMerklRewardsOperatorTransactionInfo.md)\]\>

### getBridgeTx()

```ts
getBridgeTx: (__namedParameters) => Promise<BridgeTransactionInfo[]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### recipient

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

###### sourceChain

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### targetChain

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<[`BridgeTransactionInfo`](../../sdk-common/type-aliases/BridgeTransactionInfo.md)[]\>

### getBuyOrder()

```ts
getBuyOrder: (__namedParameters) => Promise<
  | IArmadaDcaOrder
| undefined>;
```

#### Parameters

##### \_\_namedParameters

###### orderId

`string`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<
  \| [`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)
  \| `undefined`\>

### getBuyOrders()

```ts
getBuyOrders: (__namedParameters) => Promise<IArmadaDcaOrder[]>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### status?

[`ArmadaDcaOrderStatusEnum`](../../sdk-common/enumerations/ArmadaDcaOrderStatusEnum.md)

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)[]\>

### getCalculatePenaltyAmount()

```ts
getCalculatePenaltyAmount: (__namedParameters) => Promise<bigint[]>;
```

#### Parameters

##### \_\_namedParameters

###### amounts?

`bigint`[]

###### userStakes

[`UserStakeV2`](../../sdk-client/interfaces/UserStakeV2.md)[]

#### Returns

`Promise`\<`bigint`[]\>

### getCalculatePenaltyPercentage()

```ts
getCalculatePenaltyPercentage: (__namedParameters) => Promise<IPercentage[]>;
```

#### Parameters

##### \_\_namedParameters

###### userStakes

[`UserStakeV2`](../../sdk-client/interfaces/UserStakeV2.md)[]

#### Returns

`Promise`\<[`IPercentage`](../../sdk-common/interfaces/IPercentage.md)[]\>

### getChain()

```ts
getChain: (__namedParameters) => Promise<Chain>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

`number`

#### Returns

`Promise`\<[`Chain`](../../sdk-client/classes/Chain.md)\>

### getChainInfo()

```ts
getChainInfo: () => ChainInfo;
```

#### Returns

[`ChainInfo`](../../sdk-common/classes/ChainInfo.md)

### getClaimStakingV2UserRewardsTx()

```ts
getClaimStakingV2UserRewardsTx: (__namedParameters) => Promise<[ClaimTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### address

`` `0x${string}` ``

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

#### Returns

`Promise`\<\[[`ClaimTransactionInfo`](../../sdk-common/type-aliases/ClaimTransactionInfo.md)\]\>

### getCrossChainDepositTx()

```ts
getCrossChainDepositTx: (__namedParameters) => Promise<
  | [DepositTransactionInfo]
| [ApproveTransactionInfo, DepositTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### fromChainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### receiverAddressValue?

`` `0x${string}` ``

###### senderAddressValue

`` `0x${string}` ``

###### slippage

[`IPercentage`](../../sdk-common/interfaces/IPercentage.md)

###### vaultId

[`IArmadaVaultId`](../../sdk-common/interfaces/IArmadaVaultId.md)

#### Returns

`Promise`\<
  \| \[[`DepositTransactionInfo`](../../sdk-common/type-aliases/DepositTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`DepositTransactionInfo`](../../sdk-common/type-aliases/DepositTransactionInfo.md)\]\>

### getCrossChainWithdrawTx()

```ts
getCrossChainWithdrawTx: (__namedParameters) => Promise<
  | [WithdrawTransactionInfo]
| [ApproveTransactionInfo, WithdrawTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### slippage

[`IPercentage`](../../sdk-common/interfaces/IPercentage.md)

###### toChainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

###### vaultId

[`IArmadaVaultId`](../../sdk-common/interfaces/IArmadaVaultId.md)

#### Returns

`Promise`\<
  \| \[[`WithdrawTransactionInfo`](../../sdk-common/type-aliases/WithdrawTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`WithdrawTransactionInfo`](../../sdk-common/type-aliases/WithdrawTransactionInfo.md)\]\>

### getCurrentUser()

```ts
getCurrentUser: () => User;
```

#### Returns

[`User`](../../sdk-common/classes/User.md)

### getDelegateTx()

```ts
getDelegateTx: (__namedParameters) => Promise<[DelegateTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<\[[`DelegateTransactionInfo`](../../sdk-common/type-aliases/DelegateTransactionInfo.md)\]\>

### getDelegateTxV2()

```ts
getDelegateTxV2: (__namedParameters) => Promise<[DelegateTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### delegateeAddress

`` `0x${string}` ``

#### Returns

`Promise`\<\[[`DelegateTransactionInfo`](../../sdk-common/type-aliases/DelegateTransactionInfo.md)\]\>

### getDeposits()

```ts
getDeposits: (__namedParameters) => Promise<Readonly<{
  amount: ITokenAmount;
  amountUsd: IFiatCurrencyAmount;
  from: `0x${string}`;
  timestamp: number;
  to: `0x${string}`;
  txHash: `0x${string}`;
  vaultBalance: ITokenAmount;
  vaultBalanceUsd: IFiatCurrencyAmount;
}>[]>;
```

#### Parameters

##### \_\_namedParameters

###### first?

`number`

###### positionId

[`IArmadaPositionId`](../../sdk-common/interfaces/IArmadaPositionId.md)

###### skip?

`number`

#### Returns

`Promise`\<`Readonly`\<\{
  `amount`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
  `amountUsd`: [`IFiatCurrencyAmount`](../../sdk-common/interfaces/IFiatCurrencyAmount.md);
  `from`: `` `0x${string}` ``;
  `timestamp`: `number`;
  `to`: `` `0x${string}` ``;
  `txHash`: `` `0x${string}` ``;
  `vaultBalance`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
  `vaultBalanceUsd`: [`IFiatCurrencyAmount`](../../sdk-common/interfaces/IFiatCurrencyAmount.md);
\}\>[]\>

### getDepositTx()

```ts
getDepositTx: (__namedParameters) => Promise<
  | [DepositTransactionInfo]
| [ApproveTransactionInfo, DepositTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### referralCode?

`string`

###### shouldStake?

`boolean`

###### slippage

`number`

###### walletAddress

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

#### Returns

`Promise`\<
  \| \[[`DepositTransactionInfo`](../../sdk-common/type-aliases/DepositTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`DepositTransactionInfo`](../../sdk-common/type-aliases/DepositTransactionInfo.md)\]\>

### getIntentSwapsCancelOrder()

```ts
getIntentSwapsCancelOrder: (__namedParameters) => Promise<{
  result: string;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### orderId

`string`

###### publicClient

\{
  `account`: `undefined`;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `call`: (`parameters`) => `Promise`\<`CallReturnType`\>;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `createAccessList`: (`parameters`) => `Promise`\<\{
     `accessList`: `AccessList`;
     `gasUsed`: `bigint`;
  \}\>;
  `createBlockFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"block"`;
  \}\>;
  `createContractEventFilter`: \<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>;
  `createEventFilter`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>;
  `createPendingTransactionFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"transaction"`;
  \}\>;
  `dataSuffix?`: `DataSuffix`;
  `estimateContractGas`: \<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>;
  `estimateFeesPerGas`: \<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>;
  `estimateGas`: (`args`) => `Promise`\<`bigint`\>;
  `estimateMaxPriorityFeePerGas`: \<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getBalance`: (`args`) => `Promise`\<`bigint`\>;
  `getBlobBaseFee`: () => `Promise`\<`bigint`\>;
  `getBlock`: \<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
     `baseFeePerGas`: `bigint` \| `null`;
     `blobGasUsed`: `bigint`;
     `difficulty`: `bigint`;
     `excessBlobGas`: `bigint`;
     `extraData`: `` `0x${string}` ``;
     `gasLimit`: `bigint`;
     `gasUsed`: `bigint`;
     `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `miner`: `` `0x${string}` ``;
     `mixHash`: `` `0x${string}` ``;
     `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
     `parentBeaconBlockRoot?`: `` `0x${string}` ``;
     `parentHash`: `` `0x${string}` ``;
     `receiptsRoot`: `` `0x${string}` ``;
     `sealFields`: `` `0x${string}` ``[];
     `sha3Uncles`: `` `0x${string}` ``;
     `size`: `bigint`;
     `stateRoot`: `` `0x${string}` ``;
     `timestamp`: `bigint`;
     `totalDifficulty`: `bigint` \| `null`;
     `transactions`: `includeTransactions` *extends* `true` ? (
        \| \{
        `accessList?`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId?`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity?`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
     \})[] : `` `0x${string}` ``[];
     `transactionsRoot`: `` `0x${string}` ``;
     `uncles`: `` `0x${string}` ``[];
     `withdrawals?`: `Withdrawal`[];
     `withdrawalsRoot?`: `` `0x${string}` ``;
  \}\>;
  `getBlockNumber`: (`args?`) => `Promise`\<`bigint`\>;
  `getBlockTransactionCount`: (`args?`) => `Promise`\<`number`\>;
  `getBytecode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getCode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getContractEvents`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getDelegation`: (`args`) => `Promise`\<`GetDelegationReturnType`\>;
  `getEip712Domain`: (`args`) => `Promise`\<`GetEip712DomainReturnType`\>;
  `getEnsAddress`: (`args`) => `Promise`\<`GetEnsAddressReturnType`\>;
  `getEnsAvatar`: (`args`) => `Promise`\<`GetEnsAvatarReturnType`\>;
  `getEnsName`: (`args`) => `Promise`\<`GetEnsNameReturnType`\>;
  `getEnsResolver`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `getEnsText`: (`args`) => `Promise`\<`GetEnsTextReturnType`\>;
  `getFeeHistory`: (`args`) => `Promise`\<`GetFeeHistoryReturnType`\>;
  `getFilterChanges`: \<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getFilterLogs`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getGasPrice`: () => `Promise`\<`bigint`\>;
  `getLogs`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getProof`: (`args`) => `Promise`\<`GetProofReturnType`\>;
  `getStorageAt`: (`args`) => `Promise`\<`GetStorageAtReturnType`\>;
  `getTransaction`: \<`blockTag`\>(`args`) => `Promise`\<
     \| \{
     `accessList?`: `undefined`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId?`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"legacy"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity?`: `undefined`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip2930"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip1559"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes`: readonly `` `0x${string}` ``[];
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas`: `bigint`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip4844"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList`: `SignedAuthorizationList`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip7702"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
  \}\>;
  `getTransactionConfirmations`: (`args`) => `Promise`\<`bigint`\>;
  `getTransactionCount`: (`args`) => `Promise`\<`number`\>;
  `getTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `key`: `string`;
  `multicall`: \<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `readContract`: \<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>;
  `request`: `EIP1193RequestFn`\<`PublicRpcSchema`\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `simulate`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateBlocks`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateCalls`: \<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>;
  `simulateContract`: \<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `uninstallFilter`: (`args`) => `Promise`\<`boolean`\>;
  `verifyHash`: (`args`) => `Promise`\<`boolean`\>;
  `verifyMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifySiweMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifyTypedData`: (`args`) => `Promise`\<`boolean`\>;
  `waitForTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `watchBlockNumber`: (`args`) => `WatchBlockNumberReturnType`;
  `watchBlocks`: \<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`;
  `watchContractEvent`: \<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`;
  `watchEvent`: \<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`;
  `watchPendingTransactions`: (`args`) => `WatchPendingTransactionsReturnType`;
\}

###### publicClient.account

`undefined`

The Account of the Client.

###### publicClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### publicClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### publicClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### publicClient.call

(`parameters`) => `Promise`\<`CallReturnType`\>

Executes a new message call immediately without submitting a transaction to the network.

- Docs: https://viem.sh/docs/actions/public/call
- JSON-RPC Methods: [`eth_call`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const data = await client.call({
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### publicClient.chain

`Chain` \| `undefined`

Chain for the client.

###### publicClient.createAccessList

(`parameters`) => `Promise`\<\{
  `accessList`: `AccessList`;
  `gasUsed`: `bigint`;
\}\>

Creates an EIP-2930 access list that you can include in a transaction.

- Docs: https://viem.sh/docs/actions/public/createAccessList
- JSON-RPC Methods: `eth_createAccessList`

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const data = await client.createAccessList({
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.createBlockFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"block"`;
\}\>

Creates a Filter to listen for new block hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createBlockFilter
- JSON-RPC Methods: [`eth_newBlockFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newBlockFilter)

**Example**

```ts
import { createPublicClient, createBlockFilter, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await createBlockFilter(client)
// { id: "0x345a6572337856574a76364e457a4366", type: 'block' }
```

###### publicClient.createContractEventFilter

\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>

Creates a Filter to retrieve event logs that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges) or [`getFilterLogs`](https://viem.sh/docs/actions/public/getFilterLogs).

- Docs: https://viem.sh/docs/contract/createContractEventFilter

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
})
```

###### publicClient.createEventFilter

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>

Creates a [`Filter`](https://viem.sh/docs/glossary/types#filter) to listen for new events that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createEventFilter
- JSON-RPC Methods: [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xfba3912ca04dd458c843e2ee08967fc04f3579c2',
})
```

###### publicClient.createPendingTransactionFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"transaction"`;
\}\>

Creates a Filter to listen for new pending transaction hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createPendingTransactionFilter
- JSON-RPC Methods: [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
// { id: "0x345a6572337856574a76364e457a4366", type: 'transaction' }
```

###### publicClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### publicClient.estimateContractGas

\<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>

Estimates the gas required to successfully execute a contract write function call.

- Docs: https://viem.sh/docs/contract/estimateContractGas

**Remarks**

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`estimateGas` action](https://viem.sh/docs/actions/public/estimateGas) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gas = await client.estimateContractGas({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint() public']),
  functionName: 'mint',
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
})
```

###### publicClient.estimateFeesPerGas

\<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>

Returns an estimate for the fees per gas for a transaction to be included
in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateFeesPerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateFeesPerGas()
// { maxFeePerGas: ..., maxPriorityFeePerGas: ... }
```

###### publicClient.estimateGas

(`args`) => `Promise`\<`bigint`\>

Estimates the gas necessary to complete a transaction without submitting it to the network.

- Docs: https://viem.sh/docs/actions/public/estimateGas
- JSON-RPC Methods: [`eth_estimateGas`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_estimategas)

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasEstimate = await client.estimateGas({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.estimateMaxPriorityFeePerGas

\<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>

Returns an estimate for the max priority fee per gas (in wei) for a transaction
to be included in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateMaxPriorityFeePerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateMaxPriorityFeePerGas()
// 10000000n
```

###### publicClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### publicClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>

###### publicClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.getBalance

(`args`) => `Promise`\<`bigint`\>

Returns the balance of an address in wei.

- Docs: https://viem.sh/docs/actions/public/getBalance
- JSON-RPC Methods: [`eth_getBalance`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance)

**Remarks**

You can convert the balance to ether units with [`formatEther`](https://viem.sh/docs/utilities/formatEther).

```ts
const balance = await getBalance(client, {
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  blockTag: 'safe'
})
const balanceAsEther = formatEther(balance)
// "6.942"
```

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const balance = await client.getBalance({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// 10000000000000000000000n (wei)
```

###### publicClient.getBlobBaseFee

() => `Promise`\<`bigint`\>

Returns the base fee per blob gas in wei.

- Docs: https://viem.sh/docs/actions/public/getBlobBaseFee
- JSON-RPC Methods: [`eth_blobBaseFee`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blobBaseFee)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getBlobBaseFee } from 'viem/public'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blobBaseFee = await client.getBlobBaseFee()
```

###### publicClient.getBlock

\<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
  `baseFeePerGas`: `bigint` \| `null`;
  `blobGasUsed`: `bigint`;
  `difficulty`: `bigint`;
  `excessBlobGas`: `bigint`;
  `extraData`: `` `0x${string}` ``;
  `gasLimit`: `bigint`;
  `gasUsed`: `bigint`;
  `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `miner`: `` `0x${string}` ``;
  `mixHash`: `` `0x${string}` ``;
  `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
  `parentBeaconBlockRoot?`: `` `0x${string}` ``;
  `parentHash`: `` `0x${string}` ``;
  `receiptsRoot`: `` `0x${string}` ``;
  `sealFields`: `` `0x${string}` ``[];
  `sha3Uncles`: `` `0x${string}` ``;
  `size`: `bigint`;
  `stateRoot`: `` `0x${string}` ``;
  `timestamp`: `bigint`;
  `totalDifficulty`: `bigint` \| `null`;
  `transactions`: `includeTransactions` *extends* `true` ? (
     \| \{
     `accessList?`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId?`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity?`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
  \})[] : `` `0x${string}` ``[];
  `transactionsRoot`: `` `0x${string}` ``;
  `uncles`: `` `0x${string}` ``[];
  `withdrawals?`: `Withdrawal`[];
  `withdrawalsRoot?`: `` `0x${string}` ``;
\}\>

Returns information about a block at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlock
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods:
  - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getBlock()
```

###### publicClient.getBlockNumber

(`args?`) => `Promise`\<`bigint`\>

Returns the number of the most recent block seen.

- Docs: https://viem.sh/docs/actions/public/getBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods: [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blockNumber = await client.getBlockNumber()
// 69420n
```

###### publicClient.getBlockTransactionCount

(`args?`) => `Promise`\<`number`\>

Returns the number of Transactions at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlockTransactionCount
- JSON-RPC Methods:
  - Calls [`eth_getBlockTransactionCountByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockTransactionCountByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const count = await client.getBlockTransactionCount()
```

###### publicClient.getBytecode

(`args`) => `Promise`\<`GetCodeReturnType`\>

**Deprecated**

Use `getCode` instead.

###### publicClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const chainId = await client.getChainId()
// 1
```

###### publicClient.getCode

(`args`) => `Promise`\<`GetCodeReturnType`\>

Retrieves the bytecode at an address.

- Docs: https://viem.sh/docs/contract/getCode
- JSON-RPC Methods: [`eth_getCode`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getcode)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getCode({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})
```

###### publicClient.getContractEvents

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs emitted by a contract.

- Docs: https://viem.sh/docs/actions/public/getContractEvents
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { wagmiAbi } from './abi'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getContractEvents(client, {
 address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
 abi: wagmiAbi,
 eventName: 'Transfer'
})
```

###### publicClient.getDelegation

(`args`) => `Promise`\<`GetDelegationReturnType`\>

Returns the address that an account has delegated to via EIP-7702.

- Docs: https://viem.sh/docs/actions/public/getDelegation

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const delegation = await client.getDelegation({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getEip712Domain

(`args`) => `Promise`\<`GetEip712DomainReturnType`\>

Reads the EIP-712 domain from a contract, based on the ERC-5267 specification.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const domain = await client.getEip712Domain({
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
})
// {
//   domain: {
//     name: 'ExampleContract',
//     version: '1',
//     chainId: 1,
//     verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
//   },
//   fields: '0x0f',
//   extensions: [],
// }
```

###### publicClient.getEnsAddress

(`args`) => `Promise`\<`GetEnsAddressReturnType`\>

Gets address for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAddress
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAddress = await client.getEnsAddress({
  name: normalize('wevm.eth'),
})
// '0xd2135CfB216b74109775236E36d4b433F1DF507B'
```

###### publicClient.getEnsAvatar

(`args`) => `Promise`\<`GetEnsAvatarReturnType`\>

Gets the avatar of an ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAvatar
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls [`getEnsText`](https://viem.sh/docs/ens/actions/getEnsText) with `key` set to `'avatar'`.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAvatar = await client.getEnsAvatar({
  name: normalize('wevm.eth'),
})
// 'https://ipfs.io/ipfs/Qma8mnp6xV3J2cRNf3mTth5C8nV11CAnceVinc3y8jSbio'
```

###### publicClient.getEnsName

(`args`) => `Promise`\<`GetEnsNameReturnType`\>

Gets primary name for specified address.

- Docs: https://viem.sh/docs/ens/actions/getEnsName
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `reverse(bytes)` on ENS Universal Resolver Contract to "reverse resolve" the address to the primary ENS name.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensName = await client.getEnsName({
  address: '0xd2135CfB216b74109775236E36d4b433F1DF507B',
})
// 'wevm.eth'
```

###### publicClient.getEnsResolver

(`args`) => `Promise`\<`` `0x${string}` ``\>

Gets resolver for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `findResolver(bytes)` on ENS Universal Resolver Contract to retrieve the resolver of an ENS name.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const resolverAddress = await client.getEnsResolver({
  name: normalize('wevm.eth'),
})
// '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41'
```

###### publicClient.getEnsText

(`args`) => `Promise`\<`GetEnsTextReturnType`\>

Gets a text record for specified ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const twitterRecord = await client.getEnsText({
  name: normalize('wevm.eth'),
  key: 'com.twitter',
})
// 'wevm_dev'
```

###### publicClient.getFeeHistory

(`args`) => `Promise`\<`GetFeeHistoryReturnType`\>

Returns a collection of historical gas information.

- Docs: https://viem.sh/docs/actions/public/getFeeHistory
- JSON-RPC Methods: [`eth_feeHistory`](https://docs.alchemy.com/reference/eth-feehistory)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const feeHistory = await client.getFeeHistory({
  blockCount: 4,
  rewardPercentiles: [25, 75],
})
```

###### publicClient.getFilterChanges

\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of logs or hashes based on a [Filter](/docs/glossary/terms#filter) since the last time it was called.

- Docs: https://viem.sh/docs/actions/public/getFilterChanges
- JSON-RPC Methods: [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges)

**Remarks**

A Filter can be created from the following actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createContractEventFilter`](https://viem.sh/docs/contract/createContractEventFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

Depending on the type of filter, the return value will be different:

- If the filter was created with `createContractEventFilter` or `createEventFilter`, it returns a list of logs.
- If the filter was created with `createPendingTransactionFilter`, it returns a list of transaction hashes.
- If the filter was created with `createBlockFilter`, it returns a list of block hashes.

**Examples**

```ts
// Blocks
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createBlockFilter()
const hashes = await client.getFilterChanges({ filter })
```

```ts
// Contract Events
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
  eventName: 'Transfer',
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Raw Events
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Transactions
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
const hashes = await client.getFilterChanges({ filter })
```

###### publicClient.getFilterLogs

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs since the filter was created.

- Docs: https://viem.sh/docs/actions/public/getFilterLogs
- JSON-RPC Methods: [`eth_getFilterLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterlogs)

**Remarks**

`getFilterLogs` is only compatible with **event filters**.

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterLogs({ filter })
```

###### publicClient.getGasPrice

() => `Promise`\<`bigint`\>

Returns the current price of gas (in wei).

- Docs: https://viem.sh/docs/actions/public/getGasPrice
- JSON-RPC Methods: [`eth_gasPrice`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gasprice)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasPrice = await client.getGasPrice()
```

###### publicClient.getLogs

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs matching the provided parameters.

- Docs: https://viem.sh/docs/actions/public/getLogs
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/logs_event-logs
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getLogs()
```

###### publicClient.getProof

(`args`) => `Promise`\<`GetProofReturnType`\>

Returns the account and storage values of the specified account including the Merkle-proof.

- Docs: https://viem.sh/docs/actions/public/getProof
- JSON-RPC Methods:
  - Calls [`eth_getProof`](https://eips.ethereum.org/EIPS/eip-1186)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getProof({
 address: '0x...',
 storageKeys: ['0x...'],
})
```

###### publicClient.getStorageAt

(`args`) => `Promise`\<`GetStorageAtReturnType`\>

Returns the value from a storage slot at a given address.

- Docs: https://viem.sh/docs/contract/getStorageAt
- JSON-RPC Methods: [`eth_getStorageAt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getstorageat)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getStorageAt } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getStorageAt({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  slot: toHex(0),
})
```

###### publicClient.getTransaction

\<`blockTag`\>(`args`) => `Promise`\<
  \| \{
  `accessList?`: `undefined`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId?`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"legacy"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity?`: `undefined`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip2930"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip1559"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes`: readonly `` `0x${string}` ``[];
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas`: `bigint`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip4844"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList`: `SignedAuthorizationList`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip7702"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}\>

Returns information about a [Transaction](https://viem.sh/docs/glossary/terms#transaction) given a hash or block identifier.

- Docs: https://viem.sh/docs/actions/public/getTransaction
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionByHash)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transaction = await client.getTransaction({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionConfirmations

(`args`) => `Promise`\<`bigint`\>

Returns the number of blocks passed (confirmations) since the transaction was processed on a block.

- Docs: https://viem.sh/docs/actions/public/getTransactionConfirmations
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionConfirmations`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionConfirmations)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const confirmations = await client.getTransactionConfirmations({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionCount

(`args`) => `Promise`\<`number`\>

Returns the number of [Transactions](https://viem.sh/docs/glossary/terms#transaction) an Account has broadcast / sent.

- Docs: https://viem.sh/docs/actions/public/getTransactionCount
- JSON-RPC Methods: [`eth_getTransactionCount`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionCount = await client.getTransactionCount({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt) given a [Transaction](https://viem.sh/docs/glossary/terms#transaction) hash.

- Docs: https://viem.sh/docs/actions/public/getTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.getTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.key

`string`

A key for the client.

###### publicClient.multicall

\<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>

Similar to [`readContract`](https://viem.sh/docs/contract/readContract), but batches up multiple functions on a contract in a single RPC call via the [`multicall3` contract](https://github.com/mds1/multicall).

- Docs: https://viem.sh/docs/contract/multicall

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
])
const result = await client.multicall({
  contracts: [
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'balanceOf',
      args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
    },
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'totalSupply',
    },
  ],
})
// [{ result: 424122n, status: 'success' }, { result: 1000000n, status: 'success' }]
```

###### publicClient.name

`string`

A name for the client.

###### publicClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### publicClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### publicClient.readContract

\<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>

Calls a read-only function on a contract, and returns the response.

- Docs: https://viem.sh/docs/contract/readContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_reading-contracts

**Remarks**

A "read-only" function (constant function) on a Solidity contract is denoted by a `view` or `pure` keyword. They can only read the state of the contract, and cannot make any changes to it. Since read-only methods do not change the state of the contract, they do not require any gas to be executed, and can be called by any user without the need to pay for gas.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'
import { readContract } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function balanceOf(address) view returns (uint256)']),
  functionName: 'balanceOf',
  args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
})
// 424122n
```

###### publicClient.request

`EIP1193RequestFn`\<`PublicRpcSchema`\>

Request function wrapped with friendly error handling

###### publicClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.simulate

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

**Deprecated**

Use `simulateBlocks` instead.

###### publicClient.simulateBlocks

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

Simulates a set of calls on block(s) with optional block and state overrides.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateBlocks({
  blocks: [{
    blockOverrides: {
      number: 69420n,
    },
    calls: [{
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        data: '0xdeadbeef',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      },
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        value: parseEther('1'),
      },
    }],
    stateOverrides: [{
      address: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
      balance: parseEther('10'),
    }],
  }]
})
```

###### publicClient.simulateCalls

\<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>

Simulates a set of calls.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateCalls({
  account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
  calls: [{
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: parseEther('1'),
    },
  ]
})
```

###### publicClient.simulateContract

\<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>

Simulates/validates a contract interaction. This is useful for retrieving **return data** and **revert reasons** of contract write functions.

- Docs: https://viem.sh/docs/contract/simulateContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

**Remarks**

This function does not require gas to execute and _**does not**_ change the state of the blockchain. It is almost identical to [`readContract`](https://viem.sh/docs/contract/readContract), but also supports contract write functions.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32) view returns (uint32)']),
  functionName: 'mint',
  args: ['69420'],
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### publicClient.type

`string`

The type of client.

###### publicClient.uid

`string`

A unique ID for the client.

###### publicClient.uninstallFilter

(`args`) => `Promise`\<`boolean`\>

Destroys a Filter that was created from one of the following Actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

- Docs: https://viem.sh/docs/actions/public/uninstallFilter
- JSON-RPC Methods: [`eth_uninstallFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_uninstallFilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { createPendingTransactionFilter, uninstallFilter } from 'viem/public'

const filter = await client.createPendingTransactionFilter()
const uninstalled = await client.uninstallFilter({ filter })
// true
```

###### publicClient.verifyHash

(`args`) => `Promise`\<`boolean`\>

Verify that a hash was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyHash](https://viem.sh/docs/actions/public/verifyHash)

###### publicClient.verifyMessage

(`args`) => `Promise`\<`boolean`\>

Verify that a message was signed by the provided address.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/actions/public/verifyMessage](https://viem.sh/docs/actions/public/verifyMessage)

###### publicClient.verifySiweMessage

(`args`) => `Promise`\<`boolean`\>

Verifies [EIP-4361](https://eips.ethereum.org/EIPS/eip-4361) formatted message was signed.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/siwe/actions/verifySiweMessage](https://viem.sh/docs/siwe/actions/verifySiweMessage)

###### publicClient.verifyTypedData

(`args`) => `Promise`\<`boolean`\>

Verify that typed data was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyTypedData](https://viem.sh/docs/actions/public/verifyTypedData)

###### publicClient.waitForTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Waits for the [Transaction](https://viem.sh/docs/glossary/terms#transaction) to be included on a [Block](https://viem.sh/docs/glossary/terms#block) (one confirmation), and then returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt). If the Transaction reverts, then the action will throw an error.

- Docs: https://viem.sh/docs/actions/public/waitForTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - Polls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt) on each block until it has been processed.
  - If a Transaction has been replaced:
    - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) and extracts the transactions
    - Checks if one of the Transactions is a replacement
    - If so, calls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt).

**Remarks**

The `waitForTransactionReceipt` action additionally supports Replacement detection (e.g. sped up Transactions).

Transactions can be replaced when a user modifies their transaction in their wallet (to speed up or cancel). Transactions are replaced when they are sent from the same nonce.

There are 3 types of Transaction Replacement reasons:

- `repriced`: The gas price has been modified (e.g. different `maxFeePerGas`)
- `cancelled`: The Transaction has been cancelled (e.g. `value === 0n`)
- `replaced`: The Transaction has been replaced (e.g. different `value` or `data`)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.waitForTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.watchBlockNumber

(`args`) => `WatchBlockNumberReturnType`

Watches and returns incoming block numbers.

- Docs: https://viem.sh/docs/actions/public/watchBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlockNumber({
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})
```

###### publicClient.watchBlocks

\<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`

Watches and returns information for incoming blocks.

- Docs: https://viem.sh/docs/actions/public/watchBlocks
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getBlockByNumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlocks({
  onBlock: (block) => console.log(block),
})
```

###### publicClient.watchContractEvent

\<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`

Watches and returns emitted contract event logs.

- Docs: https://viem.sh/docs/contract/watchContractEvent

**Remarks**

This Action will batch up all the event logs found within the [`pollingInterval`](https://viem.sh/docs/contract/watchContractEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/contract/watchContractEvent#onLogs).

`watchContractEvent` will attempt to create an [Event Filter](https://viem.sh/docs/contract/createContractEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchContractEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchContractEvent({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
  eventName: 'Transfer',
  args: { from: '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b' },
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchEvent

\<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`

Watches and returns emitted [Event Logs](https://viem.sh/docs/glossary/terms#event-log).

- Docs: https://viem.sh/docs/actions/public/watchEvent
- JSON-RPC Methods:
  - **RPC Provider supports `eth_newFilter`:**
    - Calls [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter) to create a filter (called on initialize).
    - On a polling interval, it will call [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges).
  - **RPC Provider does not support `eth_newFilter`:**
    - Calls [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs) for each block between the polling interval.

**Remarks**

This Action will batch up all the Event Logs found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/actions/public/watchEvent#onLogs).

`watchEvent` will attempt to create an [Event Filter](https://viem.sh/docs/actions/public/createEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchEvent({
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchPendingTransactions

(`args`) => `WatchPendingTransactionsReturnType`

Watches and returns pending transaction hashes.

- Docs: https://viem.sh/docs/actions/public/watchPendingTransactions
- JSON-RPC Methods:
  - When `poll: true`
    - Calls [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter) to initialize the filter.
    - Calls [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getFilterChanges) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newPendingTransactions"` event.

**Remarks**

This Action will batch up all the pending transactions found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchPendingTransactions#pollinginterval-optional), and invoke them via [`onTransactions`](https://viem.sh/docs/actions/public/watchPendingTransactions#ontransactions).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchPendingTransactions({
  onTransactions: (hashes) => console.log(hashes),
})
```

###### walletClient

\{
  `account`: `Account` \| `undefined`;
  `addChain`: (`args`) => `Promise`\<`void`\>;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `dataSuffix?`: `DataSuffix`;
  `deployContract`: \<`abi`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `WalletRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `WalletActions`\<`Chain` \| `undefined`, `Account` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getAddresses`: () => `Promise`\<`GetAddressesReturnType`\>;
  `getCallsStatus`: (`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `getCapabilities`: \<`chainId`\>(`parameters?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (chainId extends number ? \{ atomic?: (...) \| (...); paymasterService?: (...) \| (...); unstable\_addSubAccount?: (...) \| (...); \[key: string\]: any \} : ChainIdToCapabilities\<Capabilities\<(...)\>, number\>)\[K\] \}\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getPermissions`: () => `Promise`\<`GetPermissionsReturnType`\>;
  `key`: `string`;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareAuthorization`: (`parameters`) => `Promise`\<`PrepareAuthorizationReturnType`\>;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `request`: `EIP1193RequestFn`\<`WalletRpcSchema`\>;
  `requestAddresses`: () => `Promise`\<`RequestAddressesReturnType`\>;
  `requestPermissions`: (`args`) => `Promise`\<`RequestPermissionsReturnType`\>;
  `sendCalls`: \<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
     `capabilities?`: \{
      \[`key`: `string`\]: `any`;
     \};
     `id`: `string`;
  \}\>;
  `sendCallsSync`: \<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `sendTransaction`: \<`request`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendTransactionSync`: \<`request`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>;
  `showCallsStatus`: (`parameters`) => `Promise`\<`void`\>;
  `signAuthorization`: (`parameters`) => `Promise`\<`SignAuthorizationReturnType`\>;
  `signMessage`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `signTransaction`: \<`chainOverride`, `request`\>(`args`) => `Promise`\<`TransactionSerialized`\<`GetTransactionType`\<`request`, 
     \| `request` *extends* `LegacyProperties` ? `"legacy"` : `never`
     \| `request` *extends* `EIP1559Properties` ? `"eip1559"` : `never`
     \| `request` *extends* `EIP2930Properties` ? `"eip2930"` : `never`
     \| `request` *extends* `EIP4844Properties` ? `"eip4844"` : `never`
     \| `request` *extends* `EIP7702Properties` ? `"eip7702"` : `never`
     \| ...\[...\] *extends* ... \| ... ? `Extract`\<..., ...\> : `never`\>, 
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip1559"` ? `` `0x02${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip2930"` ? `` `0x01${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip4844"` ? `` `0x03${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip7702"` ? `` `0x04${string}` `` : `never`
    \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"legacy"` ? `TransactionSerializedLegacy` : `never`\>\>;
  `signTypedData`: \<`typedData`, `primaryType`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `switchChain`: (`args`) => `Promise`\<`void`\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `waitForCallsStatus`: (`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `watchAsset`: (`args`) => `Promise`\<`boolean`\>;
  `writeContract`: \<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `writeContractSync`: \<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>;
\}

###### walletClient.account

`Account` \| `undefined`

The Account of the Client.

###### walletClient.addChain

(`args`) => `Promise`\<`void`\>

Adds an EVM chain to the wallet.

- Docs: https://viem.sh/docs/actions/wallet/addChain
- JSON-RPC Methods: [`eth_addEthereumChain`](https://eips.ethereum.org/EIPS/eip-3085)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { optimism } from 'viem/chains'

const client = createWalletClient({
  transport: custom(window.ethereum),
})
await client.addChain({ chain: optimism })
```

###### walletClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### walletClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### walletClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### walletClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### walletClient.chain

`Chain` \| `undefined`

Chain for the client.

###### walletClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### walletClient.deployContract

\<`abi`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Deploys a contract to the network, given bytecode and constructor arguments.

- Docs: https://viem.sh/docs/contract/deployContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_deploying-contracts

**Example**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const hash = await client.deployContract({
  abi: [],
  account: '0x…,
  bytecode: '0x608060405260405161083e38038061083e833981016040819052610...',
})
```

###### walletClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### walletClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `WalletRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `WalletActions`\<`Chain` \| `undefined`, `Account` \| `undefined`\>\>

###### walletClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### walletClient.getAddresses

() => `Promise`\<`GetAddressesReturnType`\>

Returns a list of account addresses owned by the wallet or client.

- Docs: https://viem.sh/docs/actions/wallet/getAddresses
- JSON-RPC Methods: [`eth_accounts`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_accounts)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const accounts = await client.getAddresses()
```

###### walletClient.getCallsStatus

(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Returns the status of a call batch that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/getCallsStatus
- JSON-RPC Methods: [`wallet_getCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const { receipts, status } = await client.getCallsStatus({ id: '0xdeadbeef' })
```

###### walletClient.getCapabilities

\<`chainId`\>(`parameters?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (chainId extends number ? \{ atomic?: (...) \| (...); paymasterService?: (...) \| (...); unstable\_addSubAccount?: (...) \| (...); \[key: string\]: any \} : ChainIdToCapabilities\<Capabilities\<(...)\>, number\>)\[K\] \}\>

Extract capabilities that a connected wallet supports (e.g. paymasters, session keys, etc).

- Docs: https://viem.sh/docs/actions/wallet/getCapabilities
- JSON-RPC Methods: [`wallet_getCapabilities`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const capabilities = await client.getCapabilities({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createWalletClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const chainId = await client.getChainId()
// 1
```

###### walletClient.getPermissions

() => `Promise`\<`GetPermissionsReturnType`\>

Gets the wallets current permissions.

- Docs: https://viem.sh/docs/actions/wallet/getPermissions
- JSON-RPC Methods: [`wallet_getPermissions`](https://eips.ethereum.org/EIPS/eip-2255)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const permissions = await client.getPermissions()
```

###### walletClient.key

`string`

A key for the client.

###### walletClient.name

`string`

A name for the client.

###### walletClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### walletClient.prepareAuthorization

(`parameters`) => `Promise`\<`PrepareAuthorizationReturnType`\>

Prepares an [EIP-7702 Authorization](https://eips.ethereum.org/EIPS/eip-7702) object for signing.
This Action will fill the required fields of the Authorization object if they are not provided (e.g. `nonce` and `chainId`).

With the prepared Authorization object, you can use [`signAuthorization`](https://viem.sh/docs/eip7702/signAuthorization) to sign over the Authorization object.

**Examples**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: http(),
})

const authorization = await client.prepareAuthorization({
  account: privateKeyToAccount('0x..'),
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})

const authorization = await client.prepareAuthorization({
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### walletClient.request

`EIP1193RequestFn`\<`WalletRpcSchema`\>

Request function wrapped with friendly error handling

###### walletClient.requestAddresses

() => `Promise`\<`RequestAddressesReturnType`\>

Requests a list of accounts managed by a wallet.

- Docs: https://viem.sh/docs/actions/wallet/requestAddresses
- JSON-RPC Methods: [`eth_requestAccounts`](https://eips.ethereum.org/EIPS/eip-1102)

Sends a request to the wallet, asking for permission to access the user's accounts. After the user accepts the request, it will return a list of accounts (addresses).

This API can be useful for dapps that need to access the user's accounts in order to execute transactions or interact with smart contracts.

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const accounts = await client.requestAddresses()
```

###### walletClient.requestPermissions

(`args`) => `Promise`\<`RequestPermissionsReturnType`\>

Requests permissions for a wallet.

- Docs: https://viem.sh/docs/actions/wallet/requestPermissions
- JSON-RPC Methods: [`wallet_requestPermissions`](https://eips.ethereum.org/EIPS/eip-2255)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const permissions = await client.requestPermissions({
  eth_accounts: {}
})
```

###### walletClient.sendCalls

\<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
  `capabilities?`: \{
   \[`key`: `string`\]: `any`;
  \};
  `id`: `string`;
\}\>

Requests the connected wallet to send a batch of calls.

- Docs: https://viem.sh/docs/actions/wallet/sendCalls
- JSON-RPC Methods: [`wallet_sendCalls`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const id = await client.sendCalls({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  calls: [
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: 69420n,
    },
  ],
})
```

###### walletClient.sendCallsSync

\<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Requests the connected wallet to send a batch of calls, and waits for the calls to be included in a block.

- Docs: https://viem.sh/docs/actions/wallet/sendCallsSync
- JSON-RPC Methods: [`wallet_sendCalls`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const status = await client.sendCallsSync({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  calls: [
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: 69420n,
    },
  ],
})
```

###### walletClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### walletClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network synchronously,
and waits for the transaction to be included in a block.

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### walletClient.sendTransaction

\<`request`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Creates, signs, and sends a new transaction to the network.

- Docs: https://viem.sh/docs/actions/wallet/sendTransaction
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_sendTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction)
  - Local Accounts: [`eth_sendRawTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendrawtransaction)

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const hash = await client.sendTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const hash = await client.sendTransaction({
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

###### walletClient.sendTransactionSync

\<`request`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>

Creates, signs, and sends a new transaction to the network synchronously.
Returns the transaction receipt.

- Docs: https://viem.sh/docs/actions/wallet/sendTransactionSync
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_sendTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction)
  - Local Accounts: [`eth_sendRawTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendrawtransaction)

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const receipt = await client.sendTransactionSync({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const receipt = await client.sendTransactionSync({
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

###### walletClient.showCallsStatus

(`parameters`) => `Promise`\<`void`\>

Requests for the wallet to show information about a call batch
that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/showCallsStatus
- JSON-RPC Methods: [`wallet_showCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

await client.showCallsStatus({ id: '0xdeadbeef' })
```

###### walletClient.signAuthorization

(`parameters`) => `Promise`\<`SignAuthorizationReturnType`\>

Signs an [EIP-7702 Authorization](https://eips.ethereum.org/EIPS/eip-7702) object.

With the calculated signature, you can:
- use [`verifyAuthorization`](https://viem.sh/docs/eip7702/verifyAuthorization) to verify the signed Authorization object,
- use [`recoverAuthorizationAddress`](https://viem.sh/docs/eip7702/recoverAuthorizationAddress) to recover the signing address from the signed Authorization object.

**Examples**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: http(),
})

const signature = await client.signAuthorization({
  account: privateKeyToAccount('0x..'),
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})

const signature = await client.signAuthorization({
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.signMessage

(`args`) => `Promise`\<`` `0x${string}` ``\>

Calculates an Ethereum-specific signature in [EIP-191 format](https://eips.ethereum.org/EIPS/eip-191): `keccak256("\x19Ethereum Signed Message:\n" + len(message) + message))`.

- Docs: https://viem.sh/docs/actions/wallet/signMessage
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`personal_sign`](https://docs.metamask.io/guide/signing-data#personal-sign)
  - Local Accounts: Signs locally. No JSON-RPC request.

With the calculated signature, you can:
- use [`verifyMessage`](https://viem.sh/docs/utilities/verifyMessage) to verify the signature,
- use [`recoverMessageAddress`](https://viem.sh/docs/utilities/recoverMessageAddress) to recover the signing address from a signature.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const signature = await client.signMessage({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  message: 'hello world',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const signature = await client.signMessage({
  message: 'hello world',
})
```

###### walletClient.signTransaction

\<`chainOverride`, `request`\>(`args`) => `Promise`\<`TransactionSerialized`\<`GetTransactionType`\<`request`, 
  \| `request` *extends* `LegacyProperties` ? `"legacy"` : `never`
  \| `request` *extends* `EIP1559Properties` ? `"eip1559"` : `never`
  \| `request` *extends* `EIP2930Properties` ? `"eip2930"` : `never`
  \| `request` *extends* `EIP4844Properties` ? `"eip4844"` : `never`
  \| `request` *extends* `EIP7702Properties` ? `"eip7702"` : `never`
  \| ...\[...\] *extends* ... \| ... ? `Extract`\<..., ...\> : `never`\>, 
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip1559"` ? `` `0x02${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip2930"` ? `` `0x01${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip4844"` ? `` `0x03${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip7702"` ? `` `0x04${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"legacy"` ? `TransactionSerializedLegacy` : `never`\>\>

Signs a transaction.

- Docs: https://viem.sh/docs/actions/wallet/signTransaction
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_signTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)
  - Local Accounts: Signs locally. No JSON-RPC request.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
const signature = await client.signTransaction(request)
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
const signature = await client.signTransaction(request)
```

###### walletClient.signTypedData

\<`typedData`, `primaryType`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Signs typed data and calculates an Ethereum-specific signature in [EIP-191 format](https://eips.ethereum.org/EIPS/eip-191): `keccak256("\x19Ethereum Signed Message:\n" + len(message) + message))`.

- Docs: https://viem.sh/docs/actions/wallet/signTypedData
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_signTypedData_v4`](https://docs.metamask.io/guide/signing-data#signtypeddata-v4)
  - Local Accounts: Signs locally. No JSON-RPC request.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const signature = await client.signTypedData({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: {
      name: 'Cow',
      wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
    },
    to: {
      name: 'Bob',
      wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    },
    contents: 'Hello, Bob!',
  },
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const signature = await client.signTypedData({
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: {
      name: 'Cow',
      wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
    },
    to: {
      name: 'Bob',
      wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    },
    contents: 'Hello, Bob!',
  },
})
```

###### walletClient.switchChain

(`args`) => `Promise`\<`void`\>

Switch the target chain in a wallet.

- Docs: https://viem.sh/docs/actions/wallet/switchChain
- JSON-RPC Methods: [`eth_switchEthereumChain`](https://eips.ethereum.org/EIPS/eip-3326)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet, optimism } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
await client.switchChain({ id: optimism.id })
```

###### walletClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### walletClient.type

`string`

The type of client.

###### walletClient.uid

`string`

A unique ID for the client.

###### walletClient.waitForCallsStatus

(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Waits for the status & receipts of a call bundle that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/waitForCallsStatus
- JSON-RPC Methods: [`wallet_getCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const { receipts, status } = await waitForCallsStatus(client, { id: '0xdeadbeef' })
```

###### walletClient.watchAsset

(`args`) => `Promise`\<`boolean`\>

Adds an EVM chain to the wallet.

- Docs: https://viem.sh/docs/actions/wallet/watchAsset
- JSON-RPC Methods: [`eth_switchEthereumChain`](https://eips.ethereum.org/EIPS/eip-747)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const success = await client.watchAsset({
  type: 'ERC20',
  options: {
    address: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    decimals: 18,
    symbol: 'WETH',
  },
})
```

###### walletClient.writeContract

\<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Executes a write function on a contract.

- Docs: https://viem.sh/docs/contract/writeContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

A "write" function on a Solidity contract modifies the state of the blockchain. These types of functions require gas to be executed, and hence a [Transaction](https://viem.sh/docs/glossary/terms) is needed to be broadcast in order to change the state.

Internally, uses a [Wallet Client](https://viem.sh/docs/clients/wallet) to call the [`sendTransaction` action](https://viem.sh/docs/actions/wallet/sendTransaction) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

__Warning: The `write` internally sends a transaction – it does not validate if the contract write will succeed (the contract may throw an error). It is highly recommended to [simulate the contract write with `contract.simulate`](https://viem.sh/docs/contract/writeContract#usage) before you execute it.__

**Examples**

```ts
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const hash = await client.writeContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
})
```

```ts
// With Validation
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const { request } = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
}
const hash = await client.writeContract(request)
```

###### walletClient.writeContractSync

\<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>

Executes a write function on a contract synchronously.
Returns the transaction receipt.

- Docs: https://viem.sh/docs/contract/writeContract

A "write" function on a Solidity contract modifies the state of the blockchain. These types of functions require gas to be executed, and hence a [Transaction](https://viem.sh/docs/glossary/terms) is needed to be broadcast in order to change the state.

Internally, uses a [Wallet Client](https://viem.sh/docs/clients/wallet) to call the [`sendTransaction` action](https://viem.sh/docs/actions/wallet/sendTransaction) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

__Warning: The `write` internally sends a transaction – it does not validate if the contract write will succeed (the contract may throw an error). It is highly recommended to [simulate the contract write with `contract.simulate`](https://viem.sh/docs/contract/writeContract#usage) before you execute it.__

**Example**

```ts
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const receipt = await client.writeContractSync({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
})
```

#### Returns

`Promise`\<\{
  `result`: `string`;
\}\>

### getIntentSwapsCheckOrder()

```ts
getIntentSwapsCheckOrder: (__namedParameters) => Promise<
  | {
  order: EnrichedOrder;
}
| null>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### orderId

`string`

#### Returns

`Promise`\<
  \| \{
  `order`: [`EnrichedOrder`](../../sdk-client/interfaces/EnrichedOrder.md);
\}
  \| `null`\>

### getIntentSwapsIsPermit2AuthorizationNeeded()

```ts
getIntentSwapsIsPermit2AuthorizationNeeded: (__namedParameters) => Promise<boolean>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### ownerAddress

`` `0x${string}` ``

###### publicClient

\{
  `account`: `undefined`;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `call`: (`parameters`) => `Promise`\<`CallReturnType`\>;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `createAccessList`: (`parameters`) => `Promise`\<\{
     `accessList`: `AccessList`;
     `gasUsed`: `bigint`;
  \}\>;
  `createBlockFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"block"`;
  \}\>;
  `createContractEventFilter`: \<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>;
  `createEventFilter`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>;
  `createPendingTransactionFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"transaction"`;
  \}\>;
  `dataSuffix?`: `DataSuffix`;
  `estimateContractGas`: \<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>;
  `estimateFeesPerGas`: \<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>;
  `estimateGas`: (`args`) => `Promise`\<`bigint`\>;
  `estimateMaxPriorityFeePerGas`: \<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getBalance`: (`args`) => `Promise`\<`bigint`\>;
  `getBlobBaseFee`: () => `Promise`\<`bigint`\>;
  `getBlock`: \<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
     `baseFeePerGas`: `bigint` \| `null`;
     `blobGasUsed`: `bigint`;
     `difficulty`: `bigint`;
     `excessBlobGas`: `bigint`;
     `extraData`: `` `0x${string}` ``;
     `gasLimit`: `bigint`;
     `gasUsed`: `bigint`;
     `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `miner`: `` `0x${string}` ``;
     `mixHash`: `` `0x${string}` ``;
     `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
     `parentBeaconBlockRoot?`: `` `0x${string}` ``;
     `parentHash`: `` `0x${string}` ``;
     `receiptsRoot`: `` `0x${string}` ``;
     `sealFields`: `` `0x${string}` ``[];
     `sha3Uncles`: `` `0x${string}` ``;
     `size`: `bigint`;
     `stateRoot`: `` `0x${string}` ``;
     `timestamp`: `bigint`;
     `totalDifficulty`: `bigint` \| `null`;
     `transactions`: `includeTransactions` *extends* `true` ? (
        \| \{
        `accessList?`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId?`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity?`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
     \})[] : `` `0x${string}` ``[];
     `transactionsRoot`: `` `0x${string}` ``;
     `uncles`: `` `0x${string}` ``[];
     `withdrawals?`: `Withdrawal`[];
     `withdrawalsRoot?`: `` `0x${string}` ``;
  \}\>;
  `getBlockNumber`: (`args?`) => `Promise`\<`bigint`\>;
  `getBlockTransactionCount`: (`args?`) => `Promise`\<`number`\>;
  `getBytecode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getCode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getContractEvents`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getDelegation`: (`args`) => `Promise`\<`GetDelegationReturnType`\>;
  `getEip712Domain`: (`args`) => `Promise`\<`GetEip712DomainReturnType`\>;
  `getEnsAddress`: (`args`) => `Promise`\<`GetEnsAddressReturnType`\>;
  `getEnsAvatar`: (`args`) => `Promise`\<`GetEnsAvatarReturnType`\>;
  `getEnsName`: (`args`) => `Promise`\<`GetEnsNameReturnType`\>;
  `getEnsResolver`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `getEnsText`: (`args`) => `Promise`\<`GetEnsTextReturnType`\>;
  `getFeeHistory`: (`args`) => `Promise`\<`GetFeeHistoryReturnType`\>;
  `getFilterChanges`: \<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getFilterLogs`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getGasPrice`: () => `Promise`\<`bigint`\>;
  `getLogs`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getProof`: (`args`) => `Promise`\<`GetProofReturnType`\>;
  `getStorageAt`: (`args`) => `Promise`\<`GetStorageAtReturnType`\>;
  `getTransaction`: \<`blockTag`\>(`args`) => `Promise`\<
     \| \{
     `accessList?`: `undefined`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId?`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"legacy"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity?`: `undefined`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip2930"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip1559"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes`: readonly `` `0x${string}` ``[];
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas`: `bigint`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip4844"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList`: `SignedAuthorizationList`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip7702"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
  \}\>;
  `getTransactionConfirmations`: (`args`) => `Promise`\<`bigint`\>;
  `getTransactionCount`: (`args`) => `Promise`\<`number`\>;
  `getTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `key`: `string`;
  `multicall`: \<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `readContract`: \<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>;
  `request`: `EIP1193RequestFn`\<`PublicRpcSchema`\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `simulate`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateBlocks`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateCalls`: \<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>;
  `simulateContract`: \<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `uninstallFilter`: (`args`) => `Promise`\<`boolean`\>;
  `verifyHash`: (`args`) => `Promise`\<`boolean`\>;
  `verifyMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifySiweMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifyTypedData`: (`args`) => `Promise`\<`boolean`\>;
  `waitForTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `watchBlockNumber`: (`args`) => `WatchBlockNumberReturnType`;
  `watchBlocks`: \<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`;
  `watchContractEvent`: \<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`;
  `watchEvent`: \<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`;
  `watchPendingTransactions`: (`args`) => `WatchPendingTransactionsReturnType`;
\}

###### publicClient.account

`undefined`

The Account of the Client.

###### publicClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### publicClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### publicClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### publicClient.call

(`parameters`) => `Promise`\<`CallReturnType`\>

Executes a new message call immediately without submitting a transaction to the network.

- Docs: https://viem.sh/docs/actions/public/call
- JSON-RPC Methods: [`eth_call`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const data = await client.call({
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### publicClient.chain

`Chain` \| `undefined`

Chain for the client.

###### publicClient.createAccessList

(`parameters`) => `Promise`\<\{
  `accessList`: `AccessList`;
  `gasUsed`: `bigint`;
\}\>

Creates an EIP-2930 access list that you can include in a transaction.

- Docs: https://viem.sh/docs/actions/public/createAccessList
- JSON-RPC Methods: `eth_createAccessList`

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const data = await client.createAccessList({
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.createBlockFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"block"`;
\}\>

Creates a Filter to listen for new block hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createBlockFilter
- JSON-RPC Methods: [`eth_newBlockFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newBlockFilter)

**Example**

```ts
import { createPublicClient, createBlockFilter, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await createBlockFilter(client)
// { id: "0x345a6572337856574a76364e457a4366", type: 'block' }
```

###### publicClient.createContractEventFilter

\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>

Creates a Filter to retrieve event logs that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges) or [`getFilterLogs`](https://viem.sh/docs/actions/public/getFilterLogs).

- Docs: https://viem.sh/docs/contract/createContractEventFilter

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
})
```

###### publicClient.createEventFilter

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>

Creates a [`Filter`](https://viem.sh/docs/glossary/types#filter) to listen for new events that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createEventFilter
- JSON-RPC Methods: [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xfba3912ca04dd458c843e2ee08967fc04f3579c2',
})
```

###### publicClient.createPendingTransactionFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"transaction"`;
\}\>

Creates a Filter to listen for new pending transaction hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createPendingTransactionFilter
- JSON-RPC Methods: [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
// { id: "0x345a6572337856574a76364e457a4366", type: 'transaction' }
```

###### publicClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### publicClient.estimateContractGas

\<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>

Estimates the gas required to successfully execute a contract write function call.

- Docs: https://viem.sh/docs/contract/estimateContractGas

**Remarks**

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`estimateGas` action](https://viem.sh/docs/actions/public/estimateGas) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gas = await client.estimateContractGas({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint() public']),
  functionName: 'mint',
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
})
```

###### publicClient.estimateFeesPerGas

\<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>

Returns an estimate for the fees per gas for a transaction to be included
in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateFeesPerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateFeesPerGas()
// { maxFeePerGas: ..., maxPriorityFeePerGas: ... }
```

###### publicClient.estimateGas

(`args`) => `Promise`\<`bigint`\>

Estimates the gas necessary to complete a transaction without submitting it to the network.

- Docs: https://viem.sh/docs/actions/public/estimateGas
- JSON-RPC Methods: [`eth_estimateGas`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_estimategas)

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasEstimate = await client.estimateGas({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.estimateMaxPriorityFeePerGas

\<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>

Returns an estimate for the max priority fee per gas (in wei) for a transaction
to be included in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateMaxPriorityFeePerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateMaxPriorityFeePerGas()
// 10000000n
```

###### publicClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### publicClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>

###### publicClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.getBalance

(`args`) => `Promise`\<`bigint`\>

Returns the balance of an address in wei.

- Docs: https://viem.sh/docs/actions/public/getBalance
- JSON-RPC Methods: [`eth_getBalance`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance)

**Remarks**

You can convert the balance to ether units with [`formatEther`](https://viem.sh/docs/utilities/formatEther).

```ts
const balance = await getBalance(client, {
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  blockTag: 'safe'
})
const balanceAsEther = formatEther(balance)
// "6.942"
```

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const balance = await client.getBalance({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// 10000000000000000000000n (wei)
```

###### publicClient.getBlobBaseFee

() => `Promise`\<`bigint`\>

Returns the base fee per blob gas in wei.

- Docs: https://viem.sh/docs/actions/public/getBlobBaseFee
- JSON-RPC Methods: [`eth_blobBaseFee`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blobBaseFee)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getBlobBaseFee } from 'viem/public'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blobBaseFee = await client.getBlobBaseFee()
```

###### publicClient.getBlock

\<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
  `baseFeePerGas`: `bigint` \| `null`;
  `blobGasUsed`: `bigint`;
  `difficulty`: `bigint`;
  `excessBlobGas`: `bigint`;
  `extraData`: `` `0x${string}` ``;
  `gasLimit`: `bigint`;
  `gasUsed`: `bigint`;
  `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `miner`: `` `0x${string}` ``;
  `mixHash`: `` `0x${string}` ``;
  `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
  `parentBeaconBlockRoot?`: `` `0x${string}` ``;
  `parentHash`: `` `0x${string}` ``;
  `receiptsRoot`: `` `0x${string}` ``;
  `sealFields`: `` `0x${string}` ``[];
  `sha3Uncles`: `` `0x${string}` ``;
  `size`: `bigint`;
  `stateRoot`: `` `0x${string}` ``;
  `timestamp`: `bigint`;
  `totalDifficulty`: `bigint` \| `null`;
  `transactions`: `includeTransactions` *extends* `true` ? (
     \| \{
     `accessList?`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId?`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity?`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
  \})[] : `` `0x${string}` ``[];
  `transactionsRoot`: `` `0x${string}` ``;
  `uncles`: `` `0x${string}` ``[];
  `withdrawals?`: `Withdrawal`[];
  `withdrawalsRoot?`: `` `0x${string}` ``;
\}\>

Returns information about a block at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlock
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods:
  - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getBlock()
```

###### publicClient.getBlockNumber

(`args?`) => `Promise`\<`bigint`\>

Returns the number of the most recent block seen.

- Docs: https://viem.sh/docs/actions/public/getBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods: [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blockNumber = await client.getBlockNumber()
// 69420n
```

###### publicClient.getBlockTransactionCount

(`args?`) => `Promise`\<`number`\>

Returns the number of Transactions at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlockTransactionCount
- JSON-RPC Methods:
  - Calls [`eth_getBlockTransactionCountByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockTransactionCountByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const count = await client.getBlockTransactionCount()
```

###### publicClient.getBytecode

(`args`) => `Promise`\<`GetCodeReturnType`\>

**Deprecated**

Use `getCode` instead.

###### publicClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const chainId = await client.getChainId()
// 1
```

###### publicClient.getCode

(`args`) => `Promise`\<`GetCodeReturnType`\>

Retrieves the bytecode at an address.

- Docs: https://viem.sh/docs/contract/getCode
- JSON-RPC Methods: [`eth_getCode`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getcode)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getCode({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})
```

###### publicClient.getContractEvents

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs emitted by a contract.

- Docs: https://viem.sh/docs/actions/public/getContractEvents
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { wagmiAbi } from './abi'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getContractEvents(client, {
 address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
 abi: wagmiAbi,
 eventName: 'Transfer'
})
```

###### publicClient.getDelegation

(`args`) => `Promise`\<`GetDelegationReturnType`\>

Returns the address that an account has delegated to via EIP-7702.

- Docs: https://viem.sh/docs/actions/public/getDelegation

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const delegation = await client.getDelegation({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getEip712Domain

(`args`) => `Promise`\<`GetEip712DomainReturnType`\>

Reads the EIP-712 domain from a contract, based on the ERC-5267 specification.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const domain = await client.getEip712Domain({
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
})
// {
//   domain: {
//     name: 'ExampleContract',
//     version: '1',
//     chainId: 1,
//     verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
//   },
//   fields: '0x0f',
//   extensions: [],
// }
```

###### publicClient.getEnsAddress

(`args`) => `Promise`\<`GetEnsAddressReturnType`\>

Gets address for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAddress
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAddress = await client.getEnsAddress({
  name: normalize('wevm.eth'),
})
// '0xd2135CfB216b74109775236E36d4b433F1DF507B'
```

###### publicClient.getEnsAvatar

(`args`) => `Promise`\<`GetEnsAvatarReturnType`\>

Gets the avatar of an ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAvatar
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls [`getEnsText`](https://viem.sh/docs/ens/actions/getEnsText) with `key` set to `'avatar'`.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAvatar = await client.getEnsAvatar({
  name: normalize('wevm.eth'),
})
// 'https://ipfs.io/ipfs/Qma8mnp6xV3J2cRNf3mTth5C8nV11CAnceVinc3y8jSbio'
```

###### publicClient.getEnsName

(`args`) => `Promise`\<`GetEnsNameReturnType`\>

Gets primary name for specified address.

- Docs: https://viem.sh/docs/ens/actions/getEnsName
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `reverse(bytes)` on ENS Universal Resolver Contract to "reverse resolve" the address to the primary ENS name.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensName = await client.getEnsName({
  address: '0xd2135CfB216b74109775236E36d4b433F1DF507B',
})
// 'wevm.eth'
```

###### publicClient.getEnsResolver

(`args`) => `Promise`\<`` `0x${string}` ``\>

Gets resolver for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `findResolver(bytes)` on ENS Universal Resolver Contract to retrieve the resolver of an ENS name.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const resolverAddress = await client.getEnsResolver({
  name: normalize('wevm.eth'),
})
// '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41'
```

###### publicClient.getEnsText

(`args`) => `Promise`\<`GetEnsTextReturnType`\>

Gets a text record for specified ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const twitterRecord = await client.getEnsText({
  name: normalize('wevm.eth'),
  key: 'com.twitter',
})
// 'wevm_dev'
```

###### publicClient.getFeeHistory

(`args`) => `Promise`\<`GetFeeHistoryReturnType`\>

Returns a collection of historical gas information.

- Docs: https://viem.sh/docs/actions/public/getFeeHistory
- JSON-RPC Methods: [`eth_feeHistory`](https://docs.alchemy.com/reference/eth-feehistory)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const feeHistory = await client.getFeeHistory({
  blockCount: 4,
  rewardPercentiles: [25, 75],
})
```

###### publicClient.getFilterChanges

\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of logs or hashes based on a [Filter](/docs/glossary/terms#filter) since the last time it was called.

- Docs: https://viem.sh/docs/actions/public/getFilterChanges
- JSON-RPC Methods: [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges)

**Remarks**

A Filter can be created from the following actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createContractEventFilter`](https://viem.sh/docs/contract/createContractEventFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

Depending on the type of filter, the return value will be different:

- If the filter was created with `createContractEventFilter` or `createEventFilter`, it returns a list of logs.
- If the filter was created with `createPendingTransactionFilter`, it returns a list of transaction hashes.
- If the filter was created with `createBlockFilter`, it returns a list of block hashes.

**Examples**

```ts
// Blocks
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createBlockFilter()
const hashes = await client.getFilterChanges({ filter })
```

```ts
// Contract Events
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
  eventName: 'Transfer',
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Raw Events
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Transactions
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
const hashes = await client.getFilterChanges({ filter })
```

###### publicClient.getFilterLogs

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs since the filter was created.

- Docs: https://viem.sh/docs/actions/public/getFilterLogs
- JSON-RPC Methods: [`eth_getFilterLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterlogs)

**Remarks**

`getFilterLogs` is only compatible with **event filters**.

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterLogs({ filter })
```

###### publicClient.getGasPrice

() => `Promise`\<`bigint`\>

Returns the current price of gas (in wei).

- Docs: https://viem.sh/docs/actions/public/getGasPrice
- JSON-RPC Methods: [`eth_gasPrice`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gasprice)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasPrice = await client.getGasPrice()
```

###### publicClient.getLogs

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs matching the provided parameters.

- Docs: https://viem.sh/docs/actions/public/getLogs
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/logs_event-logs
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getLogs()
```

###### publicClient.getProof

(`args`) => `Promise`\<`GetProofReturnType`\>

Returns the account and storage values of the specified account including the Merkle-proof.

- Docs: https://viem.sh/docs/actions/public/getProof
- JSON-RPC Methods:
  - Calls [`eth_getProof`](https://eips.ethereum.org/EIPS/eip-1186)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getProof({
 address: '0x...',
 storageKeys: ['0x...'],
})
```

###### publicClient.getStorageAt

(`args`) => `Promise`\<`GetStorageAtReturnType`\>

Returns the value from a storage slot at a given address.

- Docs: https://viem.sh/docs/contract/getStorageAt
- JSON-RPC Methods: [`eth_getStorageAt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getstorageat)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getStorageAt } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getStorageAt({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  slot: toHex(0),
})
```

###### publicClient.getTransaction

\<`blockTag`\>(`args`) => `Promise`\<
  \| \{
  `accessList?`: `undefined`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId?`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"legacy"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity?`: `undefined`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip2930"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip1559"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes`: readonly `` `0x${string}` ``[];
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas`: `bigint`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip4844"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList`: `SignedAuthorizationList`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip7702"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}\>

Returns information about a [Transaction](https://viem.sh/docs/glossary/terms#transaction) given a hash or block identifier.

- Docs: https://viem.sh/docs/actions/public/getTransaction
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionByHash)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transaction = await client.getTransaction({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionConfirmations

(`args`) => `Promise`\<`bigint`\>

Returns the number of blocks passed (confirmations) since the transaction was processed on a block.

- Docs: https://viem.sh/docs/actions/public/getTransactionConfirmations
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionConfirmations`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionConfirmations)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const confirmations = await client.getTransactionConfirmations({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionCount

(`args`) => `Promise`\<`number`\>

Returns the number of [Transactions](https://viem.sh/docs/glossary/terms#transaction) an Account has broadcast / sent.

- Docs: https://viem.sh/docs/actions/public/getTransactionCount
- JSON-RPC Methods: [`eth_getTransactionCount`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionCount = await client.getTransactionCount({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt) given a [Transaction](https://viem.sh/docs/glossary/terms#transaction) hash.

- Docs: https://viem.sh/docs/actions/public/getTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.getTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.key

`string`

A key for the client.

###### publicClient.multicall

\<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>

Similar to [`readContract`](https://viem.sh/docs/contract/readContract), but batches up multiple functions on a contract in a single RPC call via the [`multicall3` contract](https://github.com/mds1/multicall).

- Docs: https://viem.sh/docs/contract/multicall

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
])
const result = await client.multicall({
  contracts: [
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'balanceOf',
      args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
    },
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'totalSupply',
    },
  ],
})
// [{ result: 424122n, status: 'success' }, { result: 1000000n, status: 'success' }]
```

###### publicClient.name

`string`

A name for the client.

###### publicClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### publicClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### publicClient.readContract

\<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>

Calls a read-only function on a contract, and returns the response.

- Docs: https://viem.sh/docs/contract/readContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_reading-contracts

**Remarks**

A "read-only" function (constant function) on a Solidity contract is denoted by a `view` or `pure` keyword. They can only read the state of the contract, and cannot make any changes to it. Since read-only methods do not change the state of the contract, they do not require any gas to be executed, and can be called by any user without the need to pay for gas.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'
import { readContract } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function balanceOf(address) view returns (uint256)']),
  functionName: 'balanceOf',
  args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
})
// 424122n
```

###### publicClient.request

`EIP1193RequestFn`\<`PublicRpcSchema`\>

Request function wrapped with friendly error handling

###### publicClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.simulate

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

**Deprecated**

Use `simulateBlocks` instead.

###### publicClient.simulateBlocks

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

Simulates a set of calls on block(s) with optional block and state overrides.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateBlocks({
  blocks: [{
    blockOverrides: {
      number: 69420n,
    },
    calls: [{
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        data: '0xdeadbeef',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      },
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        value: parseEther('1'),
      },
    }],
    stateOverrides: [{
      address: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
      balance: parseEther('10'),
    }],
  }]
})
```

###### publicClient.simulateCalls

\<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>

Simulates a set of calls.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateCalls({
  account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
  calls: [{
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: parseEther('1'),
    },
  ]
})
```

###### publicClient.simulateContract

\<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>

Simulates/validates a contract interaction. This is useful for retrieving **return data** and **revert reasons** of contract write functions.

- Docs: https://viem.sh/docs/contract/simulateContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

**Remarks**

This function does not require gas to execute and _**does not**_ change the state of the blockchain. It is almost identical to [`readContract`](https://viem.sh/docs/contract/readContract), but also supports contract write functions.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32) view returns (uint32)']),
  functionName: 'mint',
  args: ['69420'],
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### publicClient.type

`string`

The type of client.

###### publicClient.uid

`string`

A unique ID for the client.

###### publicClient.uninstallFilter

(`args`) => `Promise`\<`boolean`\>

Destroys a Filter that was created from one of the following Actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

- Docs: https://viem.sh/docs/actions/public/uninstallFilter
- JSON-RPC Methods: [`eth_uninstallFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_uninstallFilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { createPendingTransactionFilter, uninstallFilter } from 'viem/public'

const filter = await client.createPendingTransactionFilter()
const uninstalled = await client.uninstallFilter({ filter })
// true
```

###### publicClient.verifyHash

(`args`) => `Promise`\<`boolean`\>

Verify that a hash was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyHash](https://viem.sh/docs/actions/public/verifyHash)

###### publicClient.verifyMessage

(`args`) => `Promise`\<`boolean`\>

Verify that a message was signed by the provided address.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/actions/public/verifyMessage](https://viem.sh/docs/actions/public/verifyMessage)

###### publicClient.verifySiweMessage

(`args`) => `Promise`\<`boolean`\>

Verifies [EIP-4361](https://eips.ethereum.org/EIPS/eip-4361) formatted message was signed.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/siwe/actions/verifySiweMessage](https://viem.sh/docs/siwe/actions/verifySiweMessage)

###### publicClient.verifyTypedData

(`args`) => `Promise`\<`boolean`\>

Verify that typed data was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyTypedData](https://viem.sh/docs/actions/public/verifyTypedData)

###### publicClient.waitForTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Waits for the [Transaction](https://viem.sh/docs/glossary/terms#transaction) to be included on a [Block](https://viem.sh/docs/glossary/terms#block) (one confirmation), and then returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt). If the Transaction reverts, then the action will throw an error.

- Docs: https://viem.sh/docs/actions/public/waitForTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - Polls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt) on each block until it has been processed.
  - If a Transaction has been replaced:
    - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) and extracts the transactions
    - Checks if one of the Transactions is a replacement
    - If so, calls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt).

**Remarks**

The `waitForTransactionReceipt` action additionally supports Replacement detection (e.g. sped up Transactions).

Transactions can be replaced when a user modifies their transaction in their wallet (to speed up or cancel). Transactions are replaced when they are sent from the same nonce.

There are 3 types of Transaction Replacement reasons:

- `repriced`: The gas price has been modified (e.g. different `maxFeePerGas`)
- `cancelled`: The Transaction has been cancelled (e.g. `value === 0n`)
- `replaced`: The Transaction has been replaced (e.g. different `value` or `data`)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.waitForTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.watchBlockNumber

(`args`) => `WatchBlockNumberReturnType`

Watches and returns incoming block numbers.

- Docs: https://viem.sh/docs/actions/public/watchBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlockNumber({
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})
```

###### publicClient.watchBlocks

\<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`

Watches and returns information for incoming blocks.

- Docs: https://viem.sh/docs/actions/public/watchBlocks
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getBlockByNumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlocks({
  onBlock: (block) => console.log(block),
})
```

###### publicClient.watchContractEvent

\<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`

Watches and returns emitted contract event logs.

- Docs: https://viem.sh/docs/contract/watchContractEvent

**Remarks**

This Action will batch up all the event logs found within the [`pollingInterval`](https://viem.sh/docs/contract/watchContractEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/contract/watchContractEvent#onLogs).

`watchContractEvent` will attempt to create an [Event Filter](https://viem.sh/docs/contract/createContractEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchContractEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchContractEvent({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
  eventName: 'Transfer',
  args: { from: '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b' },
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchEvent

\<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`

Watches and returns emitted [Event Logs](https://viem.sh/docs/glossary/terms#event-log).

- Docs: https://viem.sh/docs/actions/public/watchEvent
- JSON-RPC Methods:
  - **RPC Provider supports `eth_newFilter`:**
    - Calls [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter) to create a filter (called on initialize).
    - On a polling interval, it will call [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges).
  - **RPC Provider does not support `eth_newFilter`:**
    - Calls [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs) for each block between the polling interval.

**Remarks**

This Action will batch up all the Event Logs found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/actions/public/watchEvent#onLogs).

`watchEvent` will attempt to create an [Event Filter](https://viem.sh/docs/actions/public/createEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchEvent({
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchPendingTransactions

(`args`) => `WatchPendingTransactionsReturnType`

Watches and returns pending transaction hashes.

- Docs: https://viem.sh/docs/actions/public/watchPendingTransactions
- JSON-RPC Methods:
  - When `poll: true`
    - Calls [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter) to initialize the filter.
    - Calls [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getFilterChanges) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newPendingTransactions"` event.

**Remarks**

This Action will batch up all the pending transactions found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchPendingTransactions#pollinginterval-optional), and invoke them via [`onTransactions`](https://viem.sh/docs/actions/public/watchPendingTransactions#ontransactions).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchPendingTransactions({
  onTransactions: (hashes) => console.log(hashes),
})
```

###### tokenAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

### getIntentSwapsPermit2AuthorizationTx()

```ts
getIntentSwapsPermit2AuthorizationTx: (__namedParameters) => [Permit2AuthorizationTransactionInfo];
```

#### Parameters

##### \_\_namedParameters

###### tokenAddress

`` `0x${string}` ``

#### Returns

\[[`Permit2AuthorizationTransactionInfo`](../../sdk-common/type-aliases/Permit2AuthorizationTransactionInfo.md)\]

### getIntentSwapsPermit2RevokeTx()

```ts
getIntentSwapsPermit2RevokeTx: (__namedParameters) => [Permit2RevokeTransactionInfo];
```

#### Parameters

##### \_\_namedParameters

###### tokenAddress

`` `0x${string}` ``

#### Returns

\[[`Permit2RevokeTransactionInfo`](../../sdk-common/type-aliases/Permit2RevokeTransactionInfo.md)\]

### getIntentSwapsSellOrderQuote()

```ts
getIntentSwapsSellOrderQuote: (__namedParameters) => Promise<IntentQuoteData>;
```

#### Parameters

##### \_\_namedParameters

###### fromAmount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### limitPrice?

`string`

###### partiallyFillable?

`boolean`

###### receiver?

`` `0x${string}` ``

###### sender

`` `0x${string}` ``

###### slippagePercentage?

`number`

###### toToken

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

#### Returns

`Promise`\<[`IntentQuoteData`](../../sdk-common/type-aliases/IntentQuoteData.md)\>

### getIntentSwapsSendDepositOrder()

```ts
getIntentSwapsSendDepositOrder: (__namedParameters) => Promise<{
  orderId: string;
  status: "order_sent";
}>;
```

#### Parameters

##### \_\_namedParameters

###### apiKey?

`string`

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### fleetAddressValue

`` `0x${string}` ``

###### fromAmount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### limitPrice

[`IPrice`](../../sdk-common/interfaces/IPrice.md)

###### order

[`UnsignedOrder`](../../sdk-client/type-aliases/UnsignedOrder.md)

###### publicClient

\{
  `account`: `undefined`;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `call`: (`parameters`) => `Promise`\<`CallReturnType`\>;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `createAccessList`: (`parameters`) => `Promise`\<\{
     `accessList`: `AccessList`;
     `gasUsed`: `bigint`;
  \}\>;
  `createBlockFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"block"`;
  \}\>;
  `createContractEventFilter`: \<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>;
  `createEventFilter`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>;
  `createPendingTransactionFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"transaction"`;
  \}\>;
  `dataSuffix?`: `DataSuffix`;
  `estimateContractGas`: \<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>;
  `estimateFeesPerGas`: \<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>;
  `estimateGas`: (`args`) => `Promise`\<`bigint`\>;
  `estimateMaxPriorityFeePerGas`: \<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getBalance`: (`args`) => `Promise`\<`bigint`\>;
  `getBlobBaseFee`: () => `Promise`\<`bigint`\>;
  `getBlock`: \<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
     `baseFeePerGas`: `bigint` \| `null`;
     `blobGasUsed`: `bigint`;
     `difficulty`: `bigint`;
     `excessBlobGas`: `bigint`;
     `extraData`: `` `0x${string}` ``;
     `gasLimit`: `bigint`;
     `gasUsed`: `bigint`;
     `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `miner`: `` `0x${string}` ``;
     `mixHash`: `` `0x${string}` ``;
     `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
     `parentBeaconBlockRoot?`: `` `0x${string}` ``;
     `parentHash`: `` `0x${string}` ``;
     `receiptsRoot`: `` `0x${string}` ``;
     `sealFields`: `` `0x${string}` ``[];
     `sha3Uncles`: `` `0x${string}` ``;
     `size`: `bigint`;
     `stateRoot`: `` `0x${string}` ``;
     `timestamp`: `bigint`;
     `totalDifficulty`: `bigint` \| `null`;
     `transactions`: `includeTransactions` *extends* `true` ? (
        \| \{
        `accessList?`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId?`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity?`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
     \})[] : `` `0x${string}` ``[];
     `transactionsRoot`: `` `0x${string}` ``;
     `uncles`: `` `0x${string}` ``[];
     `withdrawals?`: `Withdrawal`[];
     `withdrawalsRoot?`: `` `0x${string}` ``;
  \}\>;
  `getBlockNumber`: (`args?`) => `Promise`\<`bigint`\>;
  `getBlockTransactionCount`: (`args?`) => `Promise`\<`number`\>;
  `getBytecode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getCode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getContractEvents`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getDelegation`: (`args`) => `Promise`\<`GetDelegationReturnType`\>;
  `getEip712Domain`: (`args`) => `Promise`\<`GetEip712DomainReturnType`\>;
  `getEnsAddress`: (`args`) => `Promise`\<`GetEnsAddressReturnType`\>;
  `getEnsAvatar`: (`args`) => `Promise`\<`GetEnsAvatarReturnType`\>;
  `getEnsName`: (`args`) => `Promise`\<`GetEnsNameReturnType`\>;
  `getEnsResolver`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `getEnsText`: (`args`) => `Promise`\<`GetEnsTextReturnType`\>;
  `getFeeHistory`: (`args`) => `Promise`\<`GetFeeHistoryReturnType`\>;
  `getFilterChanges`: \<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getFilterLogs`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getGasPrice`: () => `Promise`\<`bigint`\>;
  `getLogs`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getProof`: (`args`) => `Promise`\<`GetProofReturnType`\>;
  `getStorageAt`: (`args`) => `Promise`\<`GetStorageAtReturnType`\>;
  `getTransaction`: \<`blockTag`\>(`args`) => `Promise`\<
     \| \{
     `accessList?`: `undefined`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId?`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"legacy"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity?`: `undefined`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip2930"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip1559"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes`: readonly `` `0x${string}` ``[];
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas`: `bigint`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip4844"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList`: `SignedAuthorizationList`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip7702"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
  \}\>;
  `getTransactionConfirmations`: (`args`) => `Promise`\<`bigint`\>;
  `getTransactionCount`: (`args`) => `Promise`\<`number`\>;
  `getTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `key`: `string`;
  `multicall`: \<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `readContract`: \<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>;
  `request`: `EIP1193RequestFn`\<`PublicRpcSchema`\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `simulate`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateBlocks`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateCalls`: \<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>;
  `simulateContract`: \<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `uninstallFilter`: (`args`) => `Promise`\<`boolean`\>;
  `verifyHash`: (`args`) => `Promise`\<`boolean`\>;
  `verifyMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifySiweMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifyTypedData`: (`args`) => `Promise`\<`boolean`\>;
  `waitForTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `watchBlockNumber`: (`args`) => `WatchBlockNumberReturnType`;
  `watchBlocks`: \<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`;
  `watchContractEvent`: \<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`;
  `watchEvent`: \<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`;
  `watchPendingTransactions`: (`args`) => `WatchPendingTransactionsReturnType`;
\}

###### publicClient.account

`undefined`

The Account of the Client.

###### publicClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### publicClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### publicClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### publicClient.call

(`parameters`) => `Promise`\<`CallReturnType`\>

Executes a new message call immediately without submitting a transaction to the network.

- Docs: https://viem.sh/docs/actions/public/call
- JSON-RPC Methods: [`eth_call`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const data = await client.call({
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### publicClient.chain

`Chain` \| `undefined`

Chain for the client.

###### publicClient.createAccessList

(`parameters`) => `Promise`\<\{
  `accessList`: `AccessList`;
  `gasUsed`: `bigint`;
\}\>

Creates an EIP-2930 access list that you can include in a transaction.

- Docs: https://viem.sh/docs/actions/public/createAccessList
- JSON-RPC Methods: `eth_createAccessList`

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const data = await client.createAccessList({
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.createBlockFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"block"`;
\}\>

Creates a Filter to listen for new block hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createBlockFilter
- JSON-RPC Methods: [`eth_newBlockFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newBlockFilter)

**Example**

```ts
import { createPublicClient, createBlockFilter, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await createBlockFilter(client)
// { id: "0x345a6572337856574a76364e457a4366", type: 'block' }
```

###### publicClient.createContractEventFilter

\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>

Creates a Filter to retrieve event logs that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges) or [`getFilterLogs`](https://viem.sh/docs/actions/public/getFilterLogs).

- Docs: https://viem.sh/docs/contract/createContractEventFilter

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
})
```

###### publicClient.createEventFilter

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>

Creates a [`Filter`](https://viem.sh/docs/glossary/types#filter) to listen for new events that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createEventFilter
- JSON-RPC Methods: [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xfba3912ca04dd458c843e2ee08967fc04f3579c2',
})
```

###### publicClient.createPendingTransactionFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"transaction"`;
\}\>

Creates a Filter to listen for new pending transaction hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createPendingTransactionFilter
- JSON-RPC Methods: [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
// { id: "0x345a6572337856574a76364e457a4366", type: 'transaction' }
```

###### publicClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### publicClient.estimateContractGas

\<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>

Estimates the gas required to successfully execute a contract write function call.

- Docs: https://viem.sh/docs/contract/estimateContractGas

**Remarks**

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`estimateGas` action](https://viem.sh/docs/actions/public/estimateGas) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gas = await client.estimateContractGas({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint() public']),
  functionName: 'mint',
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
})
```

###### publicClient.estimateFeesPerGas

\<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>

Returns an estimate for the fees per gas for a transaction to be included
in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateFeesPerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateFeesPerGas()
// { maxFeePerGas: ..., maxPriorityFeePerGas: ... }
```

###### publicClient.estimateGas

(`args`) => `Promise`\<`bigint`\>

Estimates the gas necessary to complete a transaction without submitting it to the network.

- Docs: https://viem.sh/docs/actions/public/estimateGas
- JSON-RPC Methods: [`eth_estimateGas`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_estimategas)

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasEstimate = await client.estimateGas({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.estimateMaxPriorityFeePerGas

\<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>

Returns an estimate for the max priority fee per gas (in wei) for a transaction
to be included in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateMaxPriorityFeePerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateMaxPriorityFeePerGas()
// 10000000n
```

###### publicClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### publicClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>

###### publicClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.getBalance

(`args`) => `Promise`\<`bigint`\>

Returns the balance of an address in wei.

- Docs: https://viem.sh/docs/actions/public/getBalance
- JSON-RPC Methods: [`eth_getBalance`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance)

**Remarks**

You can convert the balance to ether units with [`formatEther`](https://viem.sh/docs/utilities/formatEther).

```ts
const balance = await getBalance(client, {
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  blockTag: 'safe'
})
const balanceAsEther = formatEther(balance)
// "6.942"
```

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const balance = await client.getBalance({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// 10000000000000000000000n (wei)
```

###### publicClient.getBlobBaseFee

() => `Promise`\<`bigint`\>

Returns the base fee per blob gas in wei.

- Docs: https://viem.sh/docs/actions/public/getBlobBaseFee
- JSON-RPC Methods: [`eth_blobBaseFee`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blobBaseFee)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getBlobBaseFee } from 'viem/public'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blobBaseFee = await client.getBlobBaseFee()
```

###### publicClient.getBlock

\<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
  `baseFeePerGas`: `bigint` \| `null`;
  `blobGasUsed`: `bigint`;
  `difficulty`: `bigint`;
  `excessBlobGas`: `bigint`;
  `extraData`: `` `0x${string}` ``;
  `gasLimit`: `bigint`;
  `gasUsed`: `bigint`;
  `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `miner`: `` `0x${string}` ``;
  `mixHash`: `` `0x${string}` ``;
  `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
  `parentBeaconBlockRoot?`: `` `0x${string}` ``;
  `parentHash`: `` `0x${string}` ``;
  `receiptsRoot`: `` `0x${string}` ``;
  `sealFields`: `` `0x${string}` ``[];
  `sha3Uncles`: `` `0x${string}` ``;
  `size`: `bigint`;
  `stateRoot`: `` `0x${string}` ``;
  `timestamp`: `bigint`;
  `totalDifficulty`: `bigint` \| `null`;
  `transactions`: `includeTransactions` *extends* `true` ? (
     \| \{
     `accessList?`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId?`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity?`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
  \})[] : `` `0x${string}` ``[];
  `transactionsRoot`: `` `0x${string}` ``;
  `uncles`: `` `0x${string}` ``[];
  `withdrawals?`: `Withdrawal`[];
  `withdrawalsRoot?`: `` `0x${string}` ``;
\}\>

Returns information about a block at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlock
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods:
  - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getBlock()
```

###### publicClient.getBlockNumber

(`args?`) => `Promise`\<`bigint`\>

Returns the number of the most recent block seen.

- Docs: https://viem.sh/docs/actions/public/getBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods: [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blockNumber = await client.getBlockNumber()
// 69420n
```

###### publicClient.getBlockTransactionCount

(`args?`) => `Promise`\<`number`\>

Returns the number of Transactions at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlockTransactionCount
- JSON-RPC Methods:
  - Calls [`eth_getBlockTransactionCountByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockTransactionCountByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const count = await client.getBlockTransactionCount()
```

###### publicClient.getBytecode

(`args`) => `Promise`\<`GetCodeReturnType`\>

**Deprecated**

Use `getCode` instead.

###### publicClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const chainId = await client.getChainId()
// 1
```

###### publicClient.getCode

(`args`) => `Promise`\<`GetCodeReturnType`\>

Retrieves the bytecode at an address.

- Docs: https://viem.sh/docs/contract/getCode
- JSON-RPC Methods: [`eth_getCode`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getcode)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getCode({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})
```

###### publicClient.getContractEvents

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs emitted by a contract.

- Docs: https://viem.sh/docs/actions/public/getContractEvents
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { wagmiAbi } from './abi'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getContractEvents(client, {
 address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
 abi: wagmiAbi,
 eventName: 'Transfer'
})
```

###### publicClient.getDelegation

(`args`) => `Promise`\<`GetDelegationReturnType`\>

Returns the address that an account has delegated to via EIP-7702.

- Docs: https://viem.sh/docs/actions/public/getDelegation

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const delegation = await client.getDelegation({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getEip712Domain

(`args`) => `Promise`\<`GetEip712DomainReturnType`\>

Reads the EIP-712 domain from a contract, based on the ERC-5267 specification.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const domain = await client.getEip712Domain({
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
})
// {
//   domain: {
//     name: 'ExampleContract',
//     version: '1',
//     chainId: 1,
//     verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
//   },
//   fields: '0x0f',
//   extensions: [],
// }
```

###### publicClient.getEnsAddress

(`args`) => `Promise`\<`GetEnsAddressReturnType`\>

Gets address for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAddress
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAddress = await client.getEnsAddress({
  name: normalize('wevm.eth'),
})
// '0xd2135CfB216b74109775236E36d4b433F1DF507B'
```

###### publicClient.getEnsAvatar

(`args`) => `Promise`\<`GetEnsAvatarReturnType`\>

Gets the avatar of an ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAvatar
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls [`getEnsText`](https://viem.sh/docs/ens/actions/getEnsText) with `key` set to `'avatar'`.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAvatar = await client.getEnsAvatar({
  name: normalize('wevm.eth'),
})
// 'https://ipfs.io/ipfs/Qma8mnp6xV3J2cRNf3mTth5C8nV11CAnceVinc3y8jSbio'
```

###### publicClient.getEnsName

(`args`) => `Promise`\<`GetEnsNameReturnType`\>

Gets primary name for specified address.

- Docs: https://viem.sh/docs/ens/actions/getEnsName
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `reverse(bytes)` on ENS Universal Resolver Contract to "reverse resolve" the address to the primary ENS name.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensName = await client.getEnsName({
  address: '0xd2135CfB216b74109775236E36d4b433F1DF507B',
})
// 'wevm.eth'
```

###### publicClient.getEnsResolver

(`args`) => `Promise`\<`` `0x${string}` ``\>

Gets resolver for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `findResolver(bytes)` on ENS Universal Resolver Contract to retrieve the resolver of an ENS name.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const resolverAddress = await client.getEnsResolver({
  name: normalize('wevm.eth'),
})
// '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41'
```

###### publicClient.getEnsText

(`args`) => `Promise`\<`GetEnsTextReturnType`\>

Gets a text record for specified ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const twitterRecord = await client.getEnsText({
  name: normalize('wevm.eth'),
  key: 'com.twitter',
})
// 'wevm_dev'
```

###### publicClient.getFeeHistory

(`args`) => `Promise`\<`GetFeeHistoryReturnType`\>

Returns a collection of historical gas information.

- Docs: https://viem.sh/docs/actions/public/getFeeHistory
- JSON-RPC Methods: [`eth_feeHistory`](https://docs.alchemy.com/reference/eth-feehistory)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const feeHistory = await client.getFeeHistory({
  blockCount: 4,
  rewardPercentiles: [25, 75],
})
```

###### publicClient.getFilterChanges

\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of logs or hashes based on a [Filter](/docs/glossary/terms#filter) since the last time it was called.

- Docs: https://viem.sh/docs/actions/public/getFilterChanges
- JSON-RPC Methods: [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges)

**Remarks**

A Filter can be created from the following actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createContractEventFilter`](https://viem.sh/docs/contract/createContractEventFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

Depending on the type of filter, the return value will be different:

- If the filter was created with `createContractEventFilter` or `createEventFilter`, it returns a list of logs.
- If the filter was created with `createPendingTransactionFilter`, it returns a list of transaction hashes.
- If the filter was created with `createBlockFilter`, it returns a list of block hashes.

**Examples**

```ts
// Blocks
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createBlockFilter()
const hashes = await client.getFilterChanges({ filter })
```

```ts
// Contract Events
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
  eventName: 'Transfer',
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Raw Events
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Transactions
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
const hashes = await client.getFilterChanges({ filter })
```

###### publicClient.getFilterLogs

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs since the filter was created.

- Docs: https://viem.sh/docs/actions/public/getFilterLogs
- JSON-RPC Methods: [`eth_getFilterLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterlogs)

**Remarks**

`getFilterLogs` is only compatible with **event filters**.

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterLogs({ filter })
```

###### publicClient.getGasPrice

() => `Promise`\<`bigint`\>

Returns the current price of gas (in wei).

- Docs: https://viem.sh/docs/actions/public/getGasPrice
- JSON-RPC Methods: [`eth_gasPrice`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gasprice)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasPrice = await client.getGasPrice()
```

###### publicClient.getLogs

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs matching the provided parameters.

- Docs: https://viem.sh/docs/actions/public/getLogs
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/logs_event-logs
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getLogs()
```

###### publicClient.getProof

(`args`) => `Promise`\<`GetProofReturnType`\>

Returns the account and storage values of the specified account including the Merkle-proof.

- Docs: https://viem.sh/docs/actions/public/getProof
- JSON-RPC Methods:
  - Calls [`eth_getProof`](https://eips.ethereum.org/EIPS/eip-1186)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getProof({
 address: '0x...',
 storageKeys: ['0x...'],
})
```

###### publicClient.getStorageAt

(`args`) => `Promise`\<`GetStorageAtReturnType`\>

Returns the value from a storage slot at a given address.

- Docs: https://viem.sh/docs/contract/getStorageAt
- JSON-RPC Methods: [`eth_getStorageAt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getstorageat)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getStorageAt } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getStorageAt({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  slot: toHex(0),
})
```

###### publicClient.getTransaction

\<`blockTag`\>(`args`) => `Promise`\<
  \| \{
  `accessList?`: `undefined`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId?`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"legacy"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity?`: `undefined`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip2930"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip1559"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes`: readonly `` `0x${string}` ``[];
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas`: `bigint`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip4844"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList`: `SignedAuthorizationList`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip7702"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}\>

Returns information about a [Transaction](https://viem.sh/docs/glossary/terms#transaction) given a hash or block identifier.

- Docs: https://viem.sh/docs/actions/public/getTransaction
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionByHash)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transaction = await client.getTransaction({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionConfirmations

(`args`) => `Promise`\<`bigint`\>

Returns the number of blocks passed (confirmations) since the transaction was processed on a block.

- Docs: https://viem.sh/docs/actions/public/getTransactionConfirmations
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionConfirmations`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionConfirmations)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const confirmations = await client.getTransactionConfirmations({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionCount

(`args`) => `Promise`\<`number`\>

Returns the number of [Transactions](https://viem.sh/docs/glossary/terms#transaction) an Account has broadcast / sent.

- Docs: https://viem.sh/docs/actions/public/getTransactionCount
- JSON-RPC Methods: [`eth_getTransactionCount`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionCount = await client.getTransactionCount({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt) given a [Transaction](https://viem.sh/docs/glossary/terms#transaction) hash.

- Docs: https://viem.sh/docs/actions/public/getTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.getTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.key

`string`

A key for the client.

###### publicClient.multicall

\<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>

Similar to [`readContract`](https://viem.sh/docs/contract/readContract), but batches up multiple functions on a contract in a single RPC call via the [`multicall3` contract](https://github.com/mds1/multicall).

- Docs: https://viem.sh/docs/contract/multicall

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
])
const result = await client.multicall({
  contracts: [
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'balanceOf',
      args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
    },
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'totalSupply',
    },
  ],
})
// [{ result: 424122n, status: 'success' }, { result: 1000000n, status: 'success' }]
```

###### publicClient.name

`string`

A name for the client.

###### publicClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### publicClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### publicClient.readContract

\<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>

Calls a read-only function on a contract, and returns the response.

- Docs: https://viem.sh/docs/contract/readContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_reading-contracts

**Remarks**

A "read-only" function (constant function) on a Solidity contract is denoted by a `view` or `pure` keyword. They can only read the state of the contract, and cannot make any changes to it. Since read-only methods do not change the state of the contract, they do not require any gas to be executed, and can be called by any user without the need to pay for gas.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'
import { readContract } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function balanceOf(address) view returns (uint256)']),
  functionName: 'balanceOf',
  args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
})
// 424122n
```

###### publicClient.request

`EIP1193RequestFn`\<`PublicRpcSchema`\>

Request function wrapped with friendly error handling

###### publicClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.simulate

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

**Deprecated**

Use `simulateBlocks` instead.

###### publicClient.simulateBlocks

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

Simulates a set of calls on block(s) with optional block and state overrides.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateBlocks({
  blocks: [{
    blockOverrides: {
      number: 69420n,
    },
    calls: [{
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        data: '0xdeadbeef',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      },
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        value: parseEther('1'),
      },
    }],
    stateOverrides: [{
      address: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
      balance: parseEther('10'),
    }],
  }]
})
```

###### publicClient.simulateCalls

\<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>

Simulates a set of calls.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateCalls({
  account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
  calls: [{
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: parseEther('1'),
    },
  ]
})
```

###### publicClient.simulateContract

\<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>

Simulates/validates a contract interaction. This is useful for retrieving **return data** and **revert reasons** of contract write functions.

- Docs: https://viem.sh/docs/contract/simulateContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

**Remarks**

This function does not require gas to execute and _**does not**_ change the state of the blockchain. It is almost identical to [`readContract`](https://viem.sh/docs/contract/readContract), but also supports contract write functions.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32) view returns (uint32)']),
  functionName: 'mint',
  args: ['69420'],
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### publicClient.type

`string`

The type of client.

###### publicClient.uid

`string`

A unique ID for the client.

###### publicClient.uninstallFilter

(`args`) => `Promise`\<`boolean`\>

Destroys a Filter that was created from one of the following Actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

- Docs: https://viem.sh/docs/actions/public/uninstallFilter
- JSON-RPC Methods: [`eth_uninstallFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_uninstallFilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { createPendingTransactionFilter, uninstallFilter } from 'viem/public'

const filter = await client.createPendingTransactionFilter()
const uninstalled = await client.uninstallFilter({ filter })
// true
```

###### publicClient.verifyHash

(`args`) => `Promise`\<`boolean`\>

Verify that a hash was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyHash](https://viem.sh/docs/actions/public/verifyHash)

###### publicClient.verifyMessage

(`args`) => `Promise`\<`boolean`\>

Verify that a message was signed by the provided address.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/actions/public/verifyMessage](https://viem.sh/docs/actions/public/verifyMessage)

###### publicClient.verifySiweMessage

(`args`) => `Promise`\<`boolean`\>

Verifies [EIP-4361](https://eips.ethereum.org/EIPS/eip-4361) formatted message was signed.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/siwe/actions/verifySiweMessage](https://viem.sh/docs/siwe/actions/verifySiweMessage)

###### publicClient.verifyTypedData

(`args`) => `Promise`\<`boolean`\>

Verify that typed data was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyTypedData](https://viem.sh/docs/actions/public/verifyTypedData)

###### publicClient.waitForTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Waits for the [Transaction](https://viem.sh/docs/glossary/terms#transaction) to be included on a [Block](https://viem.sh/docs/glossary/terms#block) (one confirmation), and then returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt). If the Transaction reverts, then the action will throw an error.

- Docs: https://viem.sh/docs/actions/public/waitForTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - Polls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt) on each block until it has been processed.
  - If a Transaction has been replaced:
    - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) and extracts the transactions
    - Checks if one of the Transactions is a replacement
    - If so, calls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt).

**Remarks**

The `waitForTransactionReceipt` action additionally supports Replacement detection (e.g. sped up Transactions).

Transactions can be replaced when a user modifies their transaction in their wallet (to speed up or cancel). Transactions are replaced when they are sent from the same nonce.

There are 3 types of Transaction Replacement reasons:

- `repriced`: The gas price has been modified (e.g. different `maxFeePerGas`)
- `cancelled`: The Transaction has been cancelled (e.g. `value === 0n`)
- `replaced`: The Transaction has been replaced (e.g. different `value` or `data`)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.waitForTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.watchBlockNumber

(`args`) => `WatchBlockNumberReturnType`

Watches and returns incoming block numbers.

- Docs: https://viem.sh/docs/actions/public/watchBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlockNumber({
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})
```

###### publicClient.watchBlocks

\<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`

Watches and returns information for incoming blocks.

- Docs: https://viem.sh/docs/actions/public/watchBlocks
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getBlockByNumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlocks({
  onBlock: (block) => console.log(block),
})
```

###### publicClient.watchContractEvent

\<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`

Watches and returns emitted contract event logs.

- Docs: https://viem.sh/docs/contract/watchContractEvent

**Remarks**

This Action will batch up all the event logs found within the [`pollingInterval`](https://viem.sh/docs/contract/watchContractEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/contract/watchContractEvent#onLogs).

`watchContractEvent` will attempt to create an [Event Filter](https://viem.sh/docs/contract/createContractEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchContractEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchContractEvent({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
  eventName: 'Transfer',
  args: { from: '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b' },
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchEvent

\<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`

Watches and returns emitted [Event Logs](https://viem.sh/docs/glossary/terms#event-log).

- Docs: https://viem.sh/docs/actions/public/watchEvent
- JSON-RPC Methods:
  - **RPC Provider supports `eth_newFilter`:**
    - Calls [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter) to create a filter (called on initialize).
    - On a polling interval, it will call [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges).
  - **RPC Provider does not support `eth_newFilter`:**
    - Calls [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs) for each block between the polling interval.

**Remarks**

This Action will batch up all the Event Logs found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/actions/public/watchEvent#onLogs).

`watchEvent` will attempt to create an [Event Filter](https://viem.sh/docs/actions/public/createEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchEvent({
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchPendingTransactions

(`args`) => `WatchPendingTransactionsReturnType`

Watches and returns pending transaction hashes.

- Docs: https://viem.sh/docs/actions/public/watchPendingTransactions
- JSON-RPC Methods:
  - When `poll: true`
    - Calls [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter) to initialize the filter.
    - Calls [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getFilterChanges) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newPendingTransactions"` event.

**Remarks**

This Action will batch up all the pending transactions found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchPendingTransactions#pollinginterval-optional), and invoke them via [`onTransactions`](https://viem.sh/docs/actions/public/watchPendingTransactions#ontransactions).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchPendingTransactions({
  onTransactions: (hashes) => console.log(hashes),
})
```

###### referralCode?

`` `0x${string}` `` = `'0x'`

###### sender

`` `0x${string}` ``

###### signTypedData

(`params`) => `Promise`\<`` `0x${string}` ``\>

###### slippagePercentage

`number`

###### toAmount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### walletClient

\{
  `account`: `Account` \| `undefined`;
  `addChain`: (`args`) => `Promise`\<`void`\>;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `dataSuffix?`: `DataSuffix`;
  `deployContract`: \<`abi`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `WalletRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `WalletActions`\<`Chain` \| `undefined`, `Account` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getAddresses`: () => `Promise`\<`GetAddressesReturnType`\>;
  `getCallsStatus`: (`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `getCapabilities`: \<`chainId`\>(`parameters?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (chainId extends number ? \{ atomic?: (...) \| (...); paymasterService?: (...) \| (...); unstable\_addSubAccount?: (...) \| (...); \[key: string\]: any \} : ChainIdToCapabilities\<Capabilities\<(...)\>, number\>)\[K\] \}\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getPermissions`: () => `Promise`\<`GetPermissionsReturnType`\>;
  `key`: `string`;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareAuthorization`: (`parameters`) => `Promise`\<`PrepareAuthorizationReturnType`\>;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `request`: `EIP1193RequestFn`\<`WalletRpcSchema`\>;
  `requestAddresses`: () => `Promise`\<`RequestAddressesReturnType`\>;
  `requestPermissions`: (`args`) => `Promise`\<`RequestPermissionsReturnType`\>;
  `sendCalls`: \<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
     `capabilities?`: \{
      \[`key`: `string`\]: `any`;
     \};
     `id`: `string`;
  \}\>;
  `sendCallsSync`: \<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `sendTransaction`: \<`request`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendTransactionSync`: \<`request`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>;
  `showCallsStatus`: (`parameters`) => `Promise`\<`void`\>;
  `signAuthorization`: (`parameters`) => `Promise`\<`SignAuthorizationReturnType`\>;
  `signMessage`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `signTransaction`: \<`chainOverride`, `request`\>(`args`) => `Promise`\<`TransactionSerialized`\<`GetTransactionType`\<`request`, 
     \| `request` *extends* `LegacyProperties` ? `"legacy"` : `never`
     \| `request` *extends* `EIP1559Properties` ? `"eip1559"` : `never`
     \| `request` *extends* `EIP2930Properties` ? `"eip2930"` : `never`
     \| `request` *extends* `EIP4844Properties` ? `"eip4844"` : `never`
     \| `request` *extends* `EIP7702Properties` ? `"eip7702"` : `never`
     \| ...\[...\] *extends* ... \| ... ? `Extract`\<..., ...\> : `never`\>, 
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip1559"` ? `` `0x02${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip2930"` ? `` `0x01${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip4844"` ? `` `0x03${string}` `` : `never`
     \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip7702"` ? `` `0x04${string}` `` : `never`
    \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"legacy"` ? `TransactionSerializedLegacy` : `never`\>\>;
  `signTypedData`: \<`typedData`, `primaryType`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `switchChain`: (`args`) => `Promise`\<`void`\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `waitForCallsStatus`: (`parameters`) => `Promise`\<\{
     `atomic`: `boolean`;
     `capabilities?`:   \| \{
      \[`key`: `string`\]: `any`;
      \}
        \| \{
      \[`key`: `string`\]: `any`;
      \};
     `chainId`: `number`;
     `id`: `string`;
     `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
     `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
     `statusCode`: `number`;
     `version`: `string`;
  \}\>;
  `watchAsset`: (`args`) => `Promise`\<`boolean`\>;
  `writeContract`: \<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>;
  `writeContractSync`: \<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>;
\}

###### walletClient.account

`Account` \| `undefined`

The Account of the Client.

###### walletClient.addChain

(`args`) => `Promise`\<`void`\>

Adds an EVM chain to the wallet.

- Docs: https://viem.sh/docs/actions/wallet/addChain
- JSON-RPC Methods: [`eth_addEthereumChain`](https://eips.ethereum.org/EIPS/eip-3085)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { optimism } from 'viem/chains'

const client = createWalletClient({
  transport: custom(window.ethereum),
})
await client.addChain({ chain: optimism })
```

###### walletClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### walletClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### walletClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### walletClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### walletClient.chain

`Chain` \| `undefined`

Chain for the client.

###### walletClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### walletClient.deployContract

\<`abi`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Deploys a contract to the network, given bytecode and constructor arguments.

- Docs: https://viem.sh/docs/contract/deployContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_deploying-contracts

**Example**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const hash = await client.deployContract({
  abi: [],
  account: '0x…,
  bytecode: '0x608060405260405161083e38038061083e833981016040819052610...',
})
```

###### walletClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### walletClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `Account` \| `undefined`, `WalletRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `WalletActions`\<`Chain` \| `undefined`, `Account` \| `undefined`\>\>

###### walletClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### walletClient.getAddresses

() => `Promise`\<`GetAddressesReturnType`\>

Returns a list of account addresses owned by the wallet or client.

- Docs: https://viem.sh/docs/actions/wallet/getAddresses
- JSON-RPC Methods: [`eth_accounts`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_accounts)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const accounts = await client.getAddresses()
```

###### walletClient.getCallsStatus

(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Returns the status of a call batch that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/getCallsStatus
- JSON-RPC Methods: [`wallet_getCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const { receipts, status } = await client.getCallsStatus({ id: '0xdeadbeef' })
```

###### walletClient.getCapabilities

\<`chainId`\>(`parameters?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (chainId extends number ? \{ atomic?: (...) \| (...); paymasterService?: (...) \| (...); unstable\_addSubAccount?: (...) \| (...); \[key: string\]: any \} : ChainIdToCapabilities\<Capabilities\<(...)\>, number\>)\[K\] \}\>

Extract capabilities that a connected wallet supports (e.g. paymasters, session keys, etc).

- Docs: https://viem.sh/docs/actions/wallet/getCapabilities
- JSON-RPC Methods: [`wallet_getCapabilities`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const capabilities = await client.getCapabilities({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createWalletClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const chainId = await client.getChainId()
// 1
```

###### walletClient.getPermissions

() => `Promise`\<`GetPermissionsReturnType`\>

Gets the wallets current permissions.

- Docs: https://viem.sh/docs/actions/wallet/getPermissions
- JSON-RPC Methods: [`wallet_getPermissions`](https://eips.ethereum.org/EIPS/eip-2255)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const permissions = await client.getPermissions()
```

###### walletClient.key

`string`

A key for the client.

###### walletClient.name

`string`

A name for the client.

###### walletClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### walletClient.prepareAuthorization

(`parameters`) => `Promise`\<`PrepareAuthorizationReturnType`\>

Prepares an [EIP-7702 Authorization](https://eips.ethereum.org/EIPS/eip-7702) object for signing.
This Action will fill the required fields of the Authorization object if they are not provided (e.g. `nonce` and `chainId`).

With the prepared Authorization object, you can use [`signAuthorization`](https://viem.sh/docs/eip7702/signAuthorization) to sign over the Authorization object.

**Examples**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: http(),
})

const authorization = await client.prepareAuthorization({
  account: privateKeyToAccount('0x..'),
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})

const authorization = await client.prepareAuthorization({
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### walletClient.request

`EIP1193RequestFn`\<`WalletRpcSchema`\>

Request function wrapped with friendly error handling

###### walletClient.requestAddresses

() => `Promise`\<`RequestAddressesReturnType`\>

Requests a list of accounts managed by a wallet.

- Docs: https://viem.sh/docs/actions/wallet/requestAddresses
- JSON-RPC Methods: [`eth_requestAccounts`](https://eips.ethereum.org/EIPS/eip-1102)

Sends a request to the wallet, asking for permission to access the user's accounts. After the user accepts the request, it will return a list of accounts (addresses).

This API can be useful for dapps that need to access the user's accounts in order to execute transactions or interact with smart contracts.

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const accounts = await client.requestAddresses()
```

###### walletClient.requestPermissions

(`args`) => `Promise`\<`RequestPermissionsReturnType`\>

Requests permissions for a wallet.

- Docs: https://viem.sh/docs/actions/wallet/requestPermissions
- JSON-RPC Methods: [`wallet_requestPermissions`](https://eips.ethereum.org/EIPS/eip-2255)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const permissions = await client.requestPermissions({
  eth_accounts: {}
})
```

###### walletClient.sendCalls

\<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
  `capabilities?`: \{
   \[`key`: `string`\]: `any`;
  \};
  `id`: `string`;
\}\>

Requests the connected wallet to send a batch of calls.

- Docs: https://viem.sh/docs/actions/wallet/sendCalls
- JSON-RPC Methods: [`wallet_sendCalls`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const id = await client.sendCalls({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  calls: [
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: 69420n,
    },
  ],
})
```

###### walletClient.sendCallsSync

\<`calls`, `chainOverride`\>(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Requests the connected wallet to send a batch of calls, and waits for the calls to be included in a block.

- Docs: https://viem.sh/docs/actions/wallet/sendCallsSync
- JSON-RPC Methods: [`wallet_sendCalls`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const status = await client.sendCallsSync({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  calls: [
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: 69420n,
    },
  ],
})
```

###### walletClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### walletClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network synchronously,
and waits for the transaction to be included in a block.

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### walletClient.sendTransaction

\<`request`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Creates, signs, and sends a new transaction to the network.

- Docs: https://viem.sh/docs/actions/wallet/sendTransaction
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_sendTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction)
  - Local Accounts: [`eth_sendRawTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendrawtransaction)

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const hash = await client.sendTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const hash = await client.sendTransaction({
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

###### walletClient.sendTransactionSync

\<`request`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>

Creates, signs, and sends a new transaction to the network synchronously.
Returns the transaction receipt.

- Docs: https://viem.sh/docs/actions/wallet/sendTransactionSync
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_sendTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendtransaction)
  - Local Accounts: [`eth_sendRawTransaction`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_sendrawtransaction)

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const receipt = await client.sendTransactionSync({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const receipt = await client.sendTransactionSync({
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: 1000000000000000000n,
})
```

###### walletClient.showCallsStatus

(`parameters`) => `Promise`\<`void`\>

Requests for the wallet to show information about a call batch
that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/showCallsStatus
- JSON-RPC Methods: [`wallet_showCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

await client.showCallsStatus({ id: '0xdeadbeef' })
```

###### walletClient.signAuthorization

(`parameters`) => `Promise`\<`SignAuthorizationReturnType`\>

Signs an [EIP-7702 Authorization](https://eips.ethereum.org/EIPS/eip-7702) object.

With the calculated signature, you can:
- use [`verifyAuthorization`](https://viem.sh/docs/eip7702/verifyAuthorization) to verify the signed Authorization object,
- use [`recoverAuthorizationAddress`](https://viem.sh/docs/eip7702/recoverAuthorizationAddress) to recover the signing address from the signed Authorization object.

**Examples**

```ts
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: http(),
})

const signature = await client.signAuthorization({
  account: privateKeyToAccount('0x..'),
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})

const signature = await client.signAuthorization({
  contractAddress: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### walletClient.signMessage

(`args`) => `Promise`\<`` `0x${string}` ``\>

Calculates an Ethereum-specific signature in [EIP-191 format](https://eips.ethereum.org/EIPS/eip-191): `keccak256("\x19Ethereum Signed Message:\n" + len(message) + message))`.

- Docs: https://viem.sh/docs/actions/wallet/signMessage
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`personal_sign`](https://docs.metamask.io/guide/signing-data#personal-sign)
  - Local Accounts: Signs locally. No JSON-RPC request.

With the calculated signature, you can:
- use [`verifyMessage`](https://viem.sh/docs/utilities/verifyMessage) to verify the signature,
- use [`recoverMessageAddress`](https://viem.sh/docs/utilities/recoverMessageAddress) to recover the signing address from a signature.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const signature = await client.signMessage({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  message: 'hello world',
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const signature = await client.signMessage({
  message: 'hello world',
})
```

###### walletClient.signTransaction

\<`chainOverride`, `request`\>(`args`) => `Promise`\<`TransactionSerialized`\<`GetTransactionType`\<`request`, 
  \| `request` *extends* `LegacyProperties` ? `"legacy"` : `never`
  \| `request` *extends* `EIP1559Properties` ? `"eip1559"` : `never`
  \| `request` *extends* `EIP2930Properties` ? `"eip2930"` : `never`
  \| `request` *extends* `EIP4844Properties` ? `"eip4844"` : `never`
  \| `request` *extends* `EIP7702Properties` ? `"eip7702"` : `never`
  \| ...\[...\] *extends* ... \| ... ? `Extract`\<..., ...\> : `never`\>, 
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip1559"` ? `` `0x02${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip2930"` ? `` `0x01${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip4844"` ? `` `0x03${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"eip7702"` ? `` `0x04${string}` `` : `never`
  \| `GetTransactionType`\<`request`, ... \| ... \| ... \| ... \| ... \| ...\> *extends* `"legacy"` ? `TransactionSerializedLegacy` : `never`\>\>

Signs a transaction.

- Docs: https://viem.sh/docs/actions/wallet/signTransaction
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_signTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)
  - Local Accounts: Signs locally. No JSON-RPC request.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
const signature = await client.signTransaction(request)
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
const signature = await client.signTransaction(request)
```

###### walletClient.signTypedData

\<`typedData`, `primaryType`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Signs typed data and calculates an Ethereum-specific signature in [EIP-191 format](https://eips.ethereum.org/EIPS/eip-191): `keccak256("\x19Ethereum Signed Message:\n" + len(message) + message))`.

- Docs: https://viem.sh/docs/actions/wallet/signTypedData
- JSON-RPC Methods:
  - JSON-RPC Accounts: [`eth_signTypedData_v4`](https://docs.metamask.io/guide/signing-data#signtypeddata-v4)
  - Local Accounts: Signs locally. No JSON-RPC request.

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const signature = await client.signTypedData({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: {
      name: 'Cow',
      wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
    },
    to: {
      name: 'Bob',
      wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    },
    contents: 'Hello, Bob!',
  },
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: http(),
})
const signature = await client.signTypedData({
  domain: {
    name: 'Ether Mail',
    version: '1',
    chainId: 1,
    verifyingContract: '0xCcCCccccCCCCcCCCCCCcCcCccCcCCCcCcccccccC',
  },
  types: {
    Person: [
      { name: 'name', type: 'string' },
      { name: 'wallet', type: 'address' },
    ],
    Mail: [
      { name: 'from', type: 'Person' },
      { name: 'to', type: 'Person' },
      { name: 'contents', type: 'string' },
    ],
  },
  primaryType: 'Mail',
  message: {
    from: {
      name: 'Cow',
      wallet: '0xCD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826',
    },
    to: {
      name: 'Bob',
      wallet: '0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB',
    },
    contents: 'Hello, Bob!',
  },
})
```

###### walletClient.switchChain

(`args`) => `Promise`\<`void`\>

Switch the target chain in a wallet.

- Docs: https://viem.sh/docs/actions/wallet/switchChain
- JSON-RPC Methods: [`eth_switchEthereumChain`](https://eips.ethereum.org/EIPS/eip-3326)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet, optimism } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
await client.switchChain({ id: optimism.id })
```

###### walletClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### walletClient.type

`string`

The type of client.

###### walletClient.uid

`string`

A unique ID for the client.

###### walletClient.waitForCallsStatus

(`parameters`) => `Promise`\<\{
  `atomic`: `boolean`;
  `capabilities?`:   \| \{
   \[`key`: `string`\]: `any`;
   \}
     \| \{
   \[`key`: `string`\]: `any`;
   \};
  `chainId`: `number`;
  `id`: `string`;
  `receipts?`: `WalletCallReceipt`\<`bigint`, ... \| ...\>[];
  `status`: `"pending"` \| `"success"` \| `"failure"` \| `undefined`;
  `statusCode`: `number`;
  `version`: `string`;
\}\>

Waits for the status & receipts of a call bundle that was sent via `sendCalls`.

- Docs: https://viem.sh/docs/actions/wallet/waitForCallsStatus
- JSON-RPC Methods: [`wallet_getCallsStatus`](https://eips.ethereum.org/EIPS/eip-5792)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const { receipts, status } = await waitForCallsStatus(client, { id: '0xdeadbeef' })
```

###### walletClient.watchAsset

(`args`) => `Promise`\<`boolean`\>

Adds an EVM chain to the wallet.

- Docs: https://viem.sh/docs/actions/wallet/watchAsset
- JSON-RPC Methods: [`eth_switchEthereumChain`](https://eips.ethereum.org/EIPS/eip-747)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const success = await client.watchAsset({
  type: 'ERC20',
  options: {
    address: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
    decimals: 18,
    symbol: 'WETH',
  },
})
```

###### walletClient.writeContract

\<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`` `0x${string}` ``\>

Executes a write function on a contract.

- Docs: https://viem.sh/docs/contract/writeContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

A "write" function on a Solidity contract modifies the state of the blockchain. These types of functions require gas to be executed, and hence a [Transaction](https://viem.sh/docs/glossary/terms) is needed to be broadcast in order to change the state.

Internally, uses a [Wallet Client](https://viem.sh/docs/clients/wallet) to call the [`sendTransaction` action](https://viem.sh/docs/actions/wallet/sendTransaction) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

__Warning: The `write` internally sends a transaction – it does not validate if the contract write will succeed (the contract may throw an error). It is highly recommended to [simulate the contract write with `contract.simulate`](https://viem.sh/docs/contract/writeContract#usage) before you execute it.__

**Examples**

```ts
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const hash = await client.writeContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
})
```

```ts
// With Validation
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const { request } = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
}
const hash = await client.writeContract(request)
```

###### walletClient.writeContractSync

\<`abi`, `functionName`, `args`, `chainOverride`\>(`args`) => `Promise`\<`TransactionReceipt`\>

Executes a write function on a contract synchronously.
Returns the transaction receipt.

- Docs: https://viem.sh/docs/contract/writeContract

A "write" function on a Solidity contract modifies the state of the blockchain. These types of functions require gas to be executed, and hence a [Transaction](https://viem.sh/docs/glossary/terms) is needed to be broadcast in order to change the state.

Internally, uses a [Wallet Client](https://viem.sh/docs/clients/wallet) to call the [`sendTransaction` action](https://viem.sh/docs/actions/wallet/sendTransaction) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

__Warning: The `write` internally sends a transaction – it does not validate if the contract write will succeed (the contract may throw an error). It is highly recommended to [simulate the contract write with `contract.simulate`](https://viem.sh/docs/contract/writeContract#usage) before you execute it.__

**Example**

```ts
import { createWalletClient, custom, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const receipt = await client.writeContractSync({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32 tokenId) nonpayable']),
  functionName: 'mint',
  args: [69420],
})
```

#### Returns

`Promise`\<\{
  `orderId`: `string`;
  `status`: `"order_sent"`;
\}\>

### getMigratablePositions()

```ts
getMigratablePositions: (__namedParameters) => Promise<{
  chainInfo: IChainInfo;
  positions: ArmadaMigratablePosition[];
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### walletAddress

`string`

#### Returns

`Promise`\<\{
  `chainInfo`: [`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md);
  `positions`: [`ArmadaMigratablePosition`](../../sdk-common/type-aliases/ArmadaMigratablePosition.md)[];
\}\>

### getMigratablePositionsApy()

```ts
getMigratablePositionsApy: (__namedParameters) => Promise<{
  apyByPositionId: Record<string, ArmadaMigratablePositionApy>;
  chainInfo: IChainInfo;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### positionIds

`` `0x${string}` ``[]

#### Returns

`Promise`\<\{
  `apyByPositionId`: `Record`\<`string`, [`ArmadaMigratablePositionApy`](../../sdk-common/type-aliases/ArmadaMigratablePositionApy.md)\>;
  `chainInfo`: [`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md);
\}\>

### getMigrateTx()

```ts
getMigrateTx: (__namedParameters) => Promise<
  | [ApproveTransactionInfo[], MigrationTransactionInfo]
| [MigrationTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### positionIds

`` `0x${string}` ``[]

###### shouldStake?

`boolean`

###### slippage

`number`

###### walletAddress

`string`

#### Returns

`Promise`\<
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md)[], [`MigrationTransactionInfo`](../../sdk-common/type-aliases/MigrationTransactionInfo.md)\]
  \| \[[`MigrationTransactionInfo`](../../sdk-common/type-aliases/MigrationTransactionInfo.md)\]\>

### getPermit2AuthorizationTx()

```ts
getPermit2AuthorizationTx: (__namedParameters) => [Permit2AuthorizationTransactionInfo];
```

#### Parameters

##### \_\_namedParameters

###### tokenAddress

`` `0x${string}` ``

#### Returns

\[[`Permit2AuthorizationTransactionInfo`](../../sdk-common/type-aliases/Permit2AuthorizationTransactionInfo.md)\]

### getPermit2RevokeTx()

```ts
getPermit2RevokeTx: (__namedParameters) => [Permit2RevokeTransactionInfo];
```

#### Parameters

##### \_\_namedParameters

###### tokenAddress

`` `0x${string}` ``

#### Returns

\[[`Permit2RevokeTransactionInfo`](../../sdk-common/type-aliases/Permit2RevokeTransactionInfo.md)\]

### getPositionHistory()

```ts
getPositionHistory: (__namedParameters) => Promise<GetPositionHistoryQuery>;
```

#### Parameters

##### \_\_namedParameters

###### positionId

[`IArmadaPositionId`](../../sdk-common/interfaces/IArmadaPositionId.md)

#### Returns

`Promise`\<`GetPositionHistoryQuery`\>

### getProtocolRevenue()

```ts
getProtocolRevenue: () => Promise<number>;
```

#### Returns

`Promise`\<`number`\>

### getProtocolTvl()

```ts
getProtocolTvl: () => Promise<number>;
```

#### Returns

`Promise`\<`number`\>

### getReferralFeesMerklClaimTx()

```ts
getReferralFeesMerklClaimTx: (__namedParameters) => Promise<
  | [MerklClaimTransactionInfo]
| undefined>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### rewardsTokensAddresses

`` `0x${string}` ``[]

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| \[[`MerklClaimTransactionInfo`](../../sdk-common/type-aliases/MerklClaimTransactionInfo.md)\]
  \| `undefined`\>

### getSpotPrice()

```ts
getSpotPrice: (__namedParameters) => Promise<ISpotPriceInfo>;
```

#### Parameters

##### \_\_namedParameters

###### baseToken

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

###### denomination?

[`Denomination`](../../sdk-common/type-aliases/Denomination.md)

#### Returns

`Promise`\<[`ISpotPriceInfo`](../../sdk-common/type-aliases/ISpotPriceInfo.md)\>

### getSpotPrices()

```ts
getSpotPrices: (__namedParameters) => Promise<SpotPricesInfo>;
```

#### Parameters

##### \_\_namedParameters

###### baseTokens

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)[]

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### quoteCurrency?

[`FiatCurrency`](../../sdk-common/enumerations/FiatCurrency.md)

#### Returns

`Promise`\<[`SpotPricesInfo`](../../sdk-common/type-aliases/SpotPricesInfo.md)\>

### getStakedBalance()

```ts
getStakedBalance: (__namedParameters) => Promise<{
  assets: ITokenAmount;
  shares: ITokenAmount;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<\{
  `assets`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
  `shares`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
\}\>

### getStakeOnBehalfTxV2()

```ts
getStakeOnBehalfTxV2: (__namedParameters) => Promise<
  | [ApproveTransactionInfo, StakeTransactionInfo]
| [StakeTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### lockupPeriod

`bigint`

###### receiver

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]
  \| \[[`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]\>

### getStakeTx()

```ts
getStakeTx: (__namedParameters) => Promise<
  | [ApproveTransactionInfo, StakeTransactionInfo]
| [StakeTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]
  \| \[[`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]\>

### getStakeTxV2()

```ts
getStakeTxV2: (__namedParameters) => Promise<
  | [ApproveTransactionInfo, StakeTransactionInfo]
| [StakeTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### lockupPeriod

`bigint`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]
  \| \[[`StakeTransactionInfo`](../../sdk-common/type-aliases/StakeTransactionInfo.md)\]\>

### getStakingBucketsInfoV2()

```ts
getStakingBucketsInfoV2: () => Promise<StakingBucketInfo[]>;
```

#### Returns

`Promise`\<`StakingBucketInfo`[]\>

### getStakingCalculateWeightedStakeV2()

```ts
getStakingCalculateWeightedStakeV2: (params) => Promise<bigint>;
```

#### Parameters

##### params

###### amount

`bigint`

###### lockupPeriod

`bigint`

#### Returns

`Promise`\<`bigint`\>

### getStakingConfigV2()

```ts
getStakingConfigV2: () => Promise<{
  stakingContractAddress: `0x${string}`;
}>;
```

#### Returns

`Promise`\<\{
  `stakingContractAddress`: `` `0x${string}` ``;
\}\>

### getStakingEarningsEstimationV2()

```ts
getStakingEarningsEstimationV2: (params) => Promise<StakingEarningsEstimationForStakes>;
```

#### Parameters

##### params

###### stakes

`object`[]

#### Returns

`Promise`\<`StakingEarningsEstimationForStakes`\>

### getStakingRevenueShareV2()

```ts
getStakingRevenueShareV2: () => Promise<{
  amount: number;
  percentage: IPercentage;
}>;
```

#### Returns

`Promise`\<\{
  `amount`: `number`;
  `percentage`: [`IPercentage`](../../sdk-common/interfaces/IPercentage.md);
\}\>

### getStakingRewardRatesV2()

```ts
getStakingRewardRatesV2: (__namedParameters) => Promise<StakingRewardRates>;
```

#### Parameters

##### \_\_namedParameters

###### rewardTokenAddress?

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

###### sumrPriceUsd?

`number`

#### Returns

`Promise`\<`StakingRewardRates`\>

### getStakingSimulationDataV2()

```ts
getStakingSimulationDataV2: (params) => Promise<StakingSimulationData>;
```

#### Parameters

##### params

###### amount

`bigint`

###### period

`bigint`

###### sumrPriceUsd?

`number`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`StakingSimulationData`\>

### getStakingStakesV2()

```ts
getStakingStakesV2: (params?) => Promise<StakingStake[]>;
```

#### Parameters

##### params?

###### first?

`number`

###### skip?

`number`

#### Returns

`Promise`\<[`StakingStake`](../../sdk-common/interfaces/StakingStake.md)[]\>

### getStakingStatsV2()

```ts
getStakingStatsV2: () => Promise<StakingStats>;
```

#### Returns

`Promise`\<`StakingStats`\>

### getStakingTotalSumrStakedV2()

```ts
getStakingTotalSumrStakedV2: () => Promise<bigint>;
```

#### Returns

`Promise`\<`bigint`\>

### getStakingTotalWeightedSupplyV2()

```ts
getStakingTotalWeightedSupplyV2: () => Promise<bigint>;
```

#### Returns

`Promise`\<`bigint`\>

### getSummerPrice()

```ts
getSummerPrice: (params?) => Promise<{
  price: number;
}>;
```

#### Parameters

##### params?

###### override?

`number`

#### Returns

`Promise`\<\{
  `price`: `number`;
\}\>

### getSummerToken()

```ts
getSummerToken: (__namedParameters) => Promise<ITokenStanalone>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

#### Returns

`Promise`\<[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)\>

### getSwapQuote()

```ts
getSwapQuote: (__namedParameters) => Promise<QuoteDataStanalone>;
```

#### Parameters

##### \_\_namedParameters

###### fromAmount

`string`

###### fromToken

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

###### slippage

`number`

###### toToken

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

#### Returns

`Promise`\<[`QuoteDataStanalone`](../../sdk-common/type-aliases/QuoteDataStanalone.md)\>

### getTargetChainInfo()

```ts
getTargetChainInfo: (specificChainId) => ChainInfo;
```

#### Parameters

##### specificChainId

`number`

#### Returns

[`ChainInfo`](../../sdk-common/classes/ChainInfo.md)

### getTipRate()

```ts
getTipRate: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### vaultId

[`IArmadaVaultId`](../../sdk-common/interfaces/IArmadaVaultId.md)

#### Returns

`Promise`\<`bigint`\>

### getTokenBySymbol()

```ts
getTokenBySymbol: (__namedParameters) => Promise<Token>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

`number`

###### symbol

`string`

#### Returns

`Promise`\<[`Token`](../../sdk-common/classes/Token.md)\>

### getUndelegateTx()

```ts
getUndelegateTx: () => Promise<[DelegateTransactionInfo]>;
```

#### Returns

`Promise`\<\[[`DelegateTransactionInfo`](../../sdk-common/type-aliases/DelegateTransactionInfo.md)\]\>

### getUnstakeFleetTokensTx()

```ts
getUnstakeFleetTokensTx: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### amountValue?

`string`

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### getUnstakeTx()

```ts
getUnstakeTx: (__namedParameters) => Promise<[UnstakeTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

#### Returns

`Promise`\<\[[`UnstakeTransactionInfo`](../../sdk-common/type-aliases/UnstakeTransactionInfo.md)\]\>

### getUnstakeTxV2()

```ts
getUnstakeTxV2: (__namedParameters) => Promise<
  | [UnstakeTransactionInfo]
| [ApproveTransactionInfo, UnstakeTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

###### userStakeIndex

`bigint`

#### Returns

`Promise`\<
  \| \[[`UnstakeTransactionInfo`](../../sdk-common/type-aliases/UnstakeTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`UnstakeTransactionInfo`](../../sdk-common/type-aliases/UnstakeTransactionInfo.md)\]\>

### getUserBalance()

```ts
getUserBalance: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

`number`

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`bigint`\>

### getUserBlendedYieldBoost()

```ts
getUserBlendedYieldBoost: (__namedParameters) => Promise<number>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`number`\>

### getUserDelegatee()

```ts
getUserDelegatee: (__namedParameters) => Promise<IAddress>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<[`IAddress`](../../sdk-common/interfaces/IAddress.md)\>

### getUserDelegateeV2()

```ts
getUserDelegateeV2: (__namedParameters) => Promise<IAddress>;
```

#### Parameters

##### \_\_namedParameters

###### userAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`IAddress`](../../sdk-common/interfaces/IAddress.md)\>

### getUserMerklRewards()

```ts
getUserMerklRewards: (__namedParameters) => Promise<{
  perChain: Partial<Record<ChainId, MerklReward[]>>;
}>;
```

#### Parameters

##### \_\_namedParameters

###### chainIds

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)[]

###### rewardsTokensAddresses

`` `0x${string}` ``[]

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<\{
  `perChain`: `Partial`\<`Record`\<[`ChainId`](../../sdk-common/type-aliases/ChainId.md), [`MerklReward`](../../sdk-client/interfaces/MerklReward.md)[]\>\>;
\}\>

### getUserPosition()

```ts
getUserPosition: (__namedParameters) => Promise<
  | IArmadaPosition
| undefined>;
```

#### Parameters

##### \_\_namedParameters

###### fleetAddress

`string`

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<
  \| [`IArmadaPosition`](../../sdk-common/interfaces/IArmadaPosition.md)
  \| `undefined`\>

### getUserPositions()

```ts
getUserPositions: (params) => Promise<IArmadaPosition[]>;
```

#### Parameters

##### params

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<[`IArmadaPosition`](../../sdk-common/interfaces/IArmadaPosition.md)[]\>

### getUserStakedBalance()

```ts
getUserStakedBalance: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`bigint`\>

### getUserStakesCount()

```ts
getUserStakesCount: (__namedParameters) => Promise<{
  userStakesCountAfter: bigint;
  userStakesCountBefore: bigint;
}>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<\{
  `userStakesCountAfter`: `bigint`;
  `userStakesCountBefore`: `bigint`;
\}\>

### getUserStakesV2()

```ts
getUserStakesV2: (__namedParameters) => Promise<UserStakeV2[]>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<[`UserStakeV2`](../../sdk-client/interfaces/UserStakeV2.md)[]\>

### getUserStakingBalanceV2()

```ts
getUserStakingBalanceV2: (__namedParameters) => Promise<StakingBalanceByBucket[]>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`StakingBalanceByBucket`[]\>

### getUserStakingEarnedV2()

```ts
getUserStakingEarnedV2: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### rewardTokenAddress?

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`bigint`\>

### getUserStakingSumrStaked()

```ts
getUserStakingSumrStaked: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`bigint`\>

### getUserStakingWeightedBalanceV2()

```ts
getUserStakingWeightedBalanceV2: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`bigint`\>

### getUserVotes()

```ts
getUserVotes: (__namedParameters) => Promise<bigint>;
```

#### Parameters

##### \_\_namedParameters

###### user

[`IUser`](../../sdk-common/interfaces/IUser.md)

#### Returns

`Promise`\<`bigint`\>

### getVaultRewardsMerklClaimTx()

```ts
getVaultRewardsMerklClaimTx: (__namedParameters) => Promise<
  | [MerklClaimTransactionInfo]
| undefined>;
```

#### Parameters

##### \_\_namedParameters

###### address

`` `0x${string}` ``

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### rewardsTokensAddresses?

`` `0x${string}` ``[]

#### Returns

`Promise`\<
  \| \[[`MerklClaimTransactionInfo`](../../sdk-common/type-aliases/MerklClaimTransactionInfo.md)\]
  \| `undefined`\>

### getVaultSwitchEnsoTx()

```ts
getVaultSwitchEnsoTx: (__namedParameters) => Promise<
  | [VaultSwitchTransactionInfo]
| [ApproveTransactionInfo, VaultSwitchTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### destinationFleetAddress

`string`

###### slippage

`number`

###### sourceFleetAddress

`string`

###### walletAddress

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

#### Returns

`Promise`\<
  \| \[[`VaultSwitchTransactionInfo`](../../sdk-common/type-aliases/VaultSwitchTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`VaultSwitchTransactionInfo`](../../sdk-common/type-aliases/VaultSwitchTransactionInfo.md)\]\>

### getVaultSwitchTx()

```ts
getVaultSwitchTx: (__namedParameters) => Promise<
  | [VaultSwitchTransactionInfo]
  | [ApproveTransactionInfo, VaultSwitchTransactionInfo]
| [ApproveTransactionInfo, ApproveTransactionInfo, VaultSwitchTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### destinationFleetAddress

`string`

###### shouldStake?

`boolean`

###### slippage

`number`

###### sourceFleetAddress

`string`

###### walletAddress

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

#### Returns

`Promise`\<
  \| \[[`VaultSwitchTransactionInfo`](../../sdk-common/type-aliases/VaultSwitchTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`VaultSwitchTransactionInfo`](../../sdk-common/type-aliases/VaultSwitchTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`VaultSwitchTransactionInfo`](../../sdk-common/type-aliases/VaultSwitchTransactionInfo.md)\]\>

### getWalletAddress()

```ts
getWalletAddress: () => Address;
```

#### Returns

[`Address`](../../sdk-common/classes/Address.md)

### getWithdrawals()

```ts
getWithdrawals: (__namedParameters) => Promise<Readonly<{
  amount: ITokenAmount;
  amountUsd: IFiatCurrencyAmount;
  from: `0x${string}`;
  timestamp: number;
  to: `0x${string}`;
  txHash: `0x${string}`;
  vaultBalance: ITokenAmount;
  vaultBalanceUsd: IFiatCurrencyAmount;
}>[]>;
```

#### Parameters

##### \_\_namedParameters

###### first?

`number`

###### positionId

[`IArmadaPositionId`](../../sdk-common/interfaces/IArmadaPositionId.md)

###### skip?

`number`

#### Returns

`Promise`\<`Readonly`\<\{
  `amount`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
  `amountUsd`: [`IFiatCurrencyAmount`](../../sdk-common/interfaces/IFiatCurrencyAmount.md);
  `from`: `` `0x${string}` ``;
  `timestamp`: `number`;
  `to`: `` `0x${string}` ``;
  `txHash`: `` `0x${string}` ``;
  `vaultBalance`: [`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md);
  `vaultBalanceUsd`: [`IFiatCurrencyAmount`](../../sdk-common/interfaces/IFiatCurrencyAmount.md);
\}\>[]\>

### getWithdrawTx()

```ts
getWithdrawTx: (__namedParameters) => Promise<
  | [WithdrawTransactionInfo]
  | [ApproveTransactionInfo, WithdrawTransactionInfo]
| [ApproveTransactionInfo, ApproveTransactionInfo, WithdrawTransactionInfo]>;
```

#### Parameters

##### \_\_namedParameters

###### amount

[`ITokenAmount`](../../sdk-common/interfaces/ITokenAmount.md)

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### slippage

`number`

###### toToken

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

###### walletAddress

[`IAddress`](../../sdk-common/interfaces/IAddress.md)

#### Returns

`Promise`\<
  \| \[[`WithdrawTransactionInfo`](../../sdk-common/type-aliases/WithdrawTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`WithdrawTransactionInfo`](../../sdk-common/type-aliases/WithdrawTransactionInfo.md)\]
  \| \[[`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`ApproveTransactionInfo`](../../sdk-common/type-aliases/ApproveTransactionInfo.md), [`WithdrawTransactionInfo`](../../sdk-common/type-aliases/WithdrawTransactionInfo.md)\]\>

### grantContractSpecificRole()

```ts
grantContractSpecificRole: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### contractAddress

`string`

###### role

[`ContractSpecificRoleName`](../../sdk-common/enumerations/ContractSpecificRoleName.md)

###### targetAddress

`string`

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### isAuthorizedStakingRewardsCallerV2()

```ts
isAuthorizedStakingRewardsCallerV2: (__namedParameters) => Promise<boolean>;
```

#### Parameters

##### \_\_namedParameters

###### authorizedCallerAddress

`` `0x${string}` ``

###### ownerAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

### isPermit2AuthorizationNeeded()

```ts
isPermit2AuthorizationNeeded: (__namedParameters) => Promise<boolean>;
```

#### Parameters

##### \_\_namedParameters

###### amount

`bigint`

###### ownerAddress

`` `0x${string}` ``

###### publicClient

\{
  `account`: `undefined`;
  `batch?`: \{
     `multicall?`:   \| `boolean`
        \| \{
        `batchSize?`: `number`;
        `deployless?`: `boolean`;
        `wait?`: `number`;
      \};
  \};
  `cacheTime`: `number`;
  `call`: (`parameters`) => `Promise`\<`CallReturnType`\>;
  `ccipRead?`:   \| `false`
     \| \{
     `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
   \};
  `chain`: `Chain` \| `undefined`;
  `createAccessList`: (`parameters`) => `Promise`\<\{
     `accessList`: `AccessList`;
     `gasUsed`: `bigint`;
  \}\>;
  `createBlockFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"block"`;
  \}\>;
  `createContractEventFilter`: \<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>;
  `createEventFilter`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>;
  `createPendingTransactionFilter`: () => `Promise`\<\{
     `id`: `` `0x${string}` ``;
     `request`: `EIP1193RequestFn`\<readonly \[\{
        `Method`: `"eth_getFilterChanges"`;
        `Parameters`: \[...\];
        `ReturnType`: ... \| ...;
      \}, \{
        `Method`: `"eth_getFilterLogs"`;
        `Parameters`: \[...\];
        `ReturnType`: ...[];
      \}, \{
        `Method`: `"eth_uninstallFilter"`;
        `Parameters`: \[...\];
        `ReturnType`: `boolean`;
     \}\]\>;
     `type`: `"transaction"`;
  \}\>;
  `dataSuffix?`: `DataSuffix`;
  `estimateContractGas`: \<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>;
  `estimateFeesPerGas`: \<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>;
  `estimateGas`: (`args`) => `Promise`\<`bigint`\>;
  `estimateMaxPriorityFeePerGas`: \<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>;
  `experimental_blockTag?`: `BlockTag`;
  `extend`: \<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>;
  `fillTransaction`: \<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>;
  `getBalance`: (`args`) => `Promise`\<`bigint`\>;
  `getBlobBaseFee`: () => `Promise`\<`bigint`\>;
  `getBlock`: \<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
     `baseFeePerGas`: `bigint` \| `null`;
     `blobGasUsed`: `bigint`;
     `difficulty`: `bigint`;
     `excessBlobGas`: `bigint`;
     `extraData`: `` `0x${string}` ``;
     `gasLimit`: `bigint`;
     `gasUsed`: `bigint`;
     `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `miner`: `` `0x${string}` ``;
     `mixHash`: `` `0x${string}` ``;
     `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
     `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
     `parentBeaconBlockRoot?`: `` `0x${string}` ``;
     `parentHash`: `` `0x${string}` ``;
     `receiptsRoot`: `` `0x${string}` ``;
     `sealFields`: `` `0x${string}` ``[];
     `sha3Uncles`: `` `0x${string}` ``;
     `size`: `bigint`;
     `stateRoot`: `` `0x${string}` ``;
     `timestamp`: `bigint`;
     `totalDifficulty`: `bigint` \| `null`;
     `transactions`: `includeTransactions` *extends* `true` ? (
        \| \{
        `accessList?`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId?`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity?`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas?`: ...;
        `maxPriorityFeePerGas?`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList?`: ...;
        `blobVersionedHashes`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
      \}
        \| \{
        `accessList`: ...;
        `authorizationList`: ...;
        `blobVersionedHashes?`: ...;
        `blockHash`: ...;
        `blockNumber`: ...;
        `chainId`: ...;
        `from`: ...;
        `gas`: ...;
        `gasPrice?`: ...;
        `hash`: ...;
        `input`: ...;
        `maxFeePerBlobGas?`: ...;
        `maxFeePerGas`: ...;
        `maxPriorityFeePerGas`: ...;
        `nonce`: ...;
        `r`: ...;
        `s`: ...;
        `to`: ...;
        `transactionIndex`: ...;
        `type`: ...;
        `typeHex`: ...;
        `v`: ...;
        `value`: ...;
        `yParity`: ...;
     \})[] : `` `0x${string}` ``[];
     `transactionsRoot`: `` `0x${string}` ``;
     `uncles`: `` `0x${string}` ``[];
     `withdrawals?`: `Withdrawal`[];
     `withdrawalsRoot?`: `` `0x${string}` ``;
  \}\>;
  `getBlockNumber`: (`args?`) => `Promise`\<`bigint`\>;
  `getBlockTransactionCount`: (`args?`) => `Promise`\<`number`\>;
  `getBytecode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getChainId`: () => `Promise`\<`number`\>;
  `getCode`: (`args`) => `Promise`\<`GetCodeReturnType`\>;
  `getContractEvents`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getDelegation`: (`args`) => `Promise`\<`GetDelegationReturnType`\>;
  `getEip712Domain`: (`args`) => `Promise`\<`GetEip712DomainReturnType`\>;
  `getEnsAddress`: (`args`) => `Promise`\<`GetEnsAddressReturnType`\>;
  `getEnsAvatar`: (`args`) => `Promise`\<`GetEnsAvatarReturnType`\>;
  `getEnsName`: (`args`) => `Promise`\<`GetEnsNameReturnType`\>;
  `getEnsResolver`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `getEnsText`: (`args`) => `Promise`\<`GetEnsTextReturnType`\>;
  `getFeeHistory`: (`args`) => `Promise`\<`GetFeeHistoryReturnType`\>;
  `getFilterChanges`: \<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getFilterLogs`: \<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getGasPrice`: () => `Promise`\<`bigint`\>;
  `getLogs`: \<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>;
  `getProof`: (`args`) => `Promise`\<`GetProofReturnType`\>;
  `getStorageAt`: (`args`) => `Promise`\<`GetStorageAtReturnType`\>;
  `getTransaction`: \<`blockTag`\>(`args`) => `Promise`\<
     \| \{
     `accessList?`: `undefined`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId?`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"legacy"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity?`: `undefined`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice`: `bigint`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas?`: `undefined`;
     `maxPriorityFeePerGas?`: `undefined`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip2930"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip1559"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList?`: `undefined`;
     `blobVersionedHashes`: readonly `` `0x${string}` ``[];
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas`: `bigint`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip4844"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
   \}
     \| \{
     `accessList`: `AccessList`;
     `authorizationList`: `SignedAuthorizationList`;
     `blobVersionedHashes?`: `undefined`;
     `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
     `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
     `chainId`: `number`;
     `from`: `` `0x${string}` ``;
     `gas`: `bigint`;
     `gasPrice?`: `undefined`;
     `hash`: `` `0x${string}` ``;
     `input`: `` `0x${string}` ``;
     `maxFeePerBlobGas?`: `undefined`;
     `maxFeePerGas`: `bigint`;
     `maxPriorityFeePerGas`: `bigint`;
     `nonce`: `number`;
     `r`: `` `0x${string}` ``;
     `s`: `` `0x${string}` ``;
     `to`: `` `0x${string}` `` \| `null`;
     `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
     `type`: `"eip7702"`;
     `typeHex`: `` `0x${string}` `` \| `null`;
     `v`: `bigint`;
     `value`: `bigint`;
     `yParity`: `number`;
  \}\>;
  `getTransactionConfirmations`: (`args`) => `Promise`\<`bigint`\>;
  `getTransactionCount`: (`args`) => `Promise`\<`number`\>;
  `getTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `key`: `string`;
  `multicall`: \<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>;
  `name`: `string`;
  `pollingInterval`: `number`;
  `prepareTransactionRequest`: \<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>;
  `readContract`: \<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>;
  `request`: `EIP1193RequestFn`\<`PublicRpcSchema`\>;
  `sendRawTransaction`: (`args`) => `Promise`\<`` `0x${string}` ``\>;
  `sendRawTransactionSync`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `simulate`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateBlocks`: \<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>;
  `simulateCalls`: \<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>;
  `simulateContract`: \<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>;
  `transport`: `TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>;
  `type`: `string`;
  `uid`: `string`;
  `uninstallFilter`: (`args`) => `Promise`\<`boolean`\>;
  `verifyHash`: (`args`) => `Promise`\<`boolean`\>;
  `verifyMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifySiweMessage`: (`args`) => `Promise`\<`boolean`\>;
  `verifyTypedData`: (`args`) => `Promise`\<`boolean`\>;
  `waitForTransactionReceipt`: (`args`) => `Promise`\<`TransactionReceipt`\>;
  `watchBlockNumber`: (`args`) => `WatchBlockNumberReturnType`;
  `watchBlocks`: \<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`;
  `watchContractEvent`: \<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`;
  `watchEvent`: \<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`;
  `watchPendingTransactions`: (`args`) => `WatchPendingTransactionsReturnType`;
\}

###### publicClient.account

`undefined`

The Account of the Client.

###### publicClient.batch?

\{
  `multicall?`:   \| `boolean`
     \| \{
     `batchSize?`: `number`;
     `deployless?`: `boolean`;
     `wait?`: `number`;
   \};
\}

Flags for batch settings.

###### publicClient.batch.multicall?

  \| `boolean`
  \| \{
  `batchSize?`: `number`;
  `deployless?`: `boolean`;
  `wait?`: `number`;
\}

Toggle to enable `eth_call` multicall aggregation.

###### publicClient.cacheTime

`number`

Time (in ms) that cached data will remain in memory.

###### publicClient.call

(`parameters`) => `Promise`\<`CallReturnType`\>

Executes a new message call immediately without submitting a transaction to the network.

- Docs: https://viem.sh/docs/actions/public/call
- JSON-RPC Methods: [`eth_call`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_call)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const data = await client.call({
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.ccipRead?

  \| `false`
  \| \{
  `request?`: (`parameters`) => `Promise`\<`` `0x${string}` ``\>;
\}

[CCIP Read](https://eips.ethereum.org/EIPS/eip-3668) configuration.

###### publicClient.chain

`Chain` \| `undefined`

Chain for the client.

###### publicClient.createAccessList

(`parameters`) => `Promise`\<\{
  `accessList`: `AccessList`;
  `gasUsed`: `bigint`;
\}\>

Creates an EIP-2930 access list that you can include in a transaction.

- Docs: https://viem.sh/docs/actions/public/createAccessList
- JSON-RPC Methods: `eth_createAccessList`

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const data = await client.createAccessList({
  data: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
})
```

###### publicClient.createBlockFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"block"`;
\}\>

Creates a Filter to listen for new block hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createBlockFilter
- JSON-RPC Methods: [`eth_newBlockFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newBlockFilter)

**Example**

```ts
import { createPublicClient, createBlockFilter, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await createBlockFilter(client)
// { id: "0x345a6572337856574a76364e457a4366", type: 'block' }
```

###### publicClient.createContractEventFilter

\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`CreateContractEventFilterReturnType`\<`abi`, `eventName`, `args`, `strict`, `fromBlock`, `toBlock`\>\>

Creates a Filter to retrieve event logs that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges) or [`getFilterLogs`](https://viem.sh/docs/actions/public/getFilterLogs).

- Docs: https://viem.sh/docs/contract/createContractEventFilter

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
})
```

###### publicClient.createEventFilter

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`, `_EventName`, `_Args`\>(`args?`) => `Promise`\<\{ \[K in string \| number \| symbol\]: Filter\<"event", abiEvents, \_EventName, \_Args, strict, fromBlock, toBlock\>\[K\] \}\>

Creates a [`Filter`](https://viem.sh/docs/glossary/types#filter) to listen for new events that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createEventFilter
- JSON-RPC Methods: [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xfba3912ca04dd458c843e2ee08967fc04f3579c2',
})
```

###### publicClient.createPendingTransactionFilter

() => `Promise`\<\{
  `id`: `` `0x${string}` ``;
  `request`: `EIP1193RequestFn`\<readonly \[\{
     `Method`: `"eth_getFilterChanges"`;
     `Parameters`: \[...\];
     `ReturnType`: ... \| ...;
   \}, \{
     `Method`: `"eth_getFilterLogs"`;
     `Parameters`: \[...\];
     `ReturnType`: ...[];
   \}, \{
     `Method`: `"eth_uninstallFilter"`;
     `Parameters`: \[...\];
     `ReturnType`: `boolean`;
  \}\]\>;
  `type`: `"transaction"`;
\}\>

Creates a Filter to listen for new pending transaction hashes that can be used with [`getFilterChanges`](https://viem.sh/docs/actions/public/getFilterChanges).

- Docs: https://viem.sh/docs/actions/public/createPendingTransactionFilter
- JSON-RPC Methods: [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
// { id: "0x345a6572337856574a76364e457a4366", type: 'transaction' }
```

###### publicClient.dataSuffix?

`DataSuffix`

Data suffix to append to transaction data.

###### publicClient.estimateContractGas

\<`chain`, `abi`, `functionName`, `args`\>(`args`) => `Promise`\<`bigint`\>

Estimates the gas required to successfully execute a contract write function call.

- Docs: https://viem.sh/docs/contract/estimateContractGas

**Remarks**

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`estimateGas` action](https://viem.sh/docs/actions/public/estimateGas) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gas = await client.estimateContractGas({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint() public']),
  functionName: 'mint',
  account: '0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
})
```

###### publicClient.estimateFeesPerGas

\<`chainOverride`, `type`\>(`args?`) => `Promise`\<`EstimateFeesPerGasReturnType`\<`type`\>\>

Returns an estimate for the fees per gas for a transaction to be included
in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateFeesPerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateFeesPerGas()
// { maxFeePerGas: ..., maxPriorityFeePerGas: ... }
```

###### publicClient.estimateGas

(`args`) => `Promise`\<`bigint`\>

Estimates the gas necessary to complete a transaction without submitting it to the network.

- Docs: https://viem.sh/docs/actions/public/estimateGas
- JSON-RPC Methods: [`eth_estimateGas`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_estimategas)

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasEstimate = await client.estimateGas({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.estimateMaxPriorityFeePerGas

\<`chainOverride`\>(`args?`) => `Promise`\<`bigint`\>

Returns an estimate for the max priority fee per gas (in wei) for a transaction
to be included in the next block.

- Docs: https://viem.sh/docs/actions/public/estimateMaxPriorityFeePerGas

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const maxPriorityFeePerGas = await client.estimateMaxPriorityFeePerGas()
// 10000000n
```

###### publicClient.experimental_blockTag?

`BlockTag`

Default block tag to use for RPC requests.

###### publicClient.extend

\<`client`\>(`fn`) => `Client`\<`Transport`, `Chain` \| `undefined`, `undefined`, `PublicRpcSchema`, \{ \[K in string \| number \| symbol\]: client\[K\] \} & `PublicActions`\<`Transport`, `Chain` \| `undefined`\>\>

###### publicClient.fillTransaction

\<`chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`FillTransactionReturnType`\<`Chain` \| `undefined`, `chainOverride`\>\>

Fills a transaction request with the necessary fields to be signed over.

- Docs: https://viem.sh/docs/actions/public/fillTransaction

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.fillTransaction({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
  value: parseEther('1'),
})
```

###### publicClient.getBalance

(`args`) => `Promise`\<`bigint`\>

Returns the balance of an address in wei.

- Docs: https://viem.sh/docs/actions/public/getBalance
- JSON-RPC Methods: [`eth_getBalance`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getbalance)

**Remarks**

You can convert the balance to ether units with [`formatEther`](https://viem.sh/docs/utilities/formatEther).

```ts
const balance = await getBalance(client, {
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  blockTag: 'safe'
})
const balanceAsEther = formatEther(balance)
// "6.942"
```

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const balance = await client.getBalance({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
// 10000000000000000000000n (wei)
```

###### publicClient.getBlobBaseFee

() => `Promise`\<`bigint`\>

Returns the base fee per blob gas in wei.

- Docs: https://viem.sh/docs/actions/public/getBlobBaseFee
- JSON-RPC Methods: [`eth_blobBaseFee`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blobBaseFee)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getBlobBaseFee } from 'viem/public'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blobBaseFee = await client.getBlobBaseFee()
```

###### publicClient.getBlock

\<`includeTransactions`, `blockTag`\>(`args?`) => `Promise`\<\{
  `baseFeePerGas`: `bigint` \| `null`;
  `blobGasUsed`: `bigint`;
  `difficulty`: `bigint`;
  `excessBlobGas`: `bigint`;
  `extraData`: `` `0x${string}` ``;
  `gasLimit`: `bigint`;
  `gasUsed`: `bigint`;
  `hash`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `logsBloom`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `miner`: `` `0x${string}` ``;
  `mixHash`: `` `0x${string}` ``;
  `nonce`: `blockTag` *extends* `"pending"` ? `null` : `` `0x${string}` ``;
  `number`: `blockTag` *extends* `"pending"` ? `null` : `bigint`;
  `parentBeaconBlockRoot?`: `` `0x${string}` ``;
  `parentHash`: `` `0x${string}` ``;
  `receiptsRoot`: `` `0x${string}` ``;
  `sealFields`: `` `0x${string}` ``[];
  `sha3Uncles`: `` `0x${string}` ``;
  `size`: `bigint`;
  `stateRoot`: `` `0x${string}` ``;
  `timestamp`: `bigint`;
  `totalDifficulty`: `bigint` \| `null`;
  `transactions`: `includeTransactions` *extends* `true` ? (
     \| \{
     `accessList?`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId?`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity?`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas?`: ...;
     `maxPriorityFeePerGas?`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList?`: ...;
     `blobVersionedHashes`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
   \}
     \| \{
     `accessList`: ...;
     `authorizationList`: ...;
     `blobVersionedHashes?`: ...;
     `blockHash`: ...;
     `blockNumber`: ...;
     `chainId`: ...;
     `from`: ...;
     `gas`: ...;
     `gasPrice?`: ...;
     `hash`: ...;
     `input`: ...;
     `maxFeePerBlobGas?`: ...;
     `maxFeePerGas`: ...;
     `maxPriorityFeePerGas`: ...;
     `nonce`: ...;
     `r`: ...;
     `s`: ...;
     `to`: ...;
     `transactionIndex`: ...;
     `type`: ...;
     `typeHex`: ...;
     `v`: ...;
     `value`: ...;
     `yParity`: ...;
  \})[] : `` `0x${string}` ``[];
  `transactionsRoot`: `` `0x${string}` ``;
  `uncles`: `` `0x${string}` ``[];
  `withdrawals?`: `Withdrawal`[];
  `withdrawalsRoot?`: `` `0x${string}` ``;
\}\>

Returns information about a block at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlock
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods:
  - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getBlock()
```

###### publicClient.getBlockNumber

(`args?`) => `Promise`\<`bigint`\>

Returns the number of the most recent block seen.

- Docs: https://viem.sh/docs/actions/public/getBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_fetching-blocks
- JSON-RPC Methods: [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const blockNumber = await client.getBlockNumber()
// 69420n
```

###### publicClient.getBlockTransactionCount

(`args?`) => `Promise`\<`number`\>

Returns the number of Transactions at a block number, hash, or tag.

- Docs: https://viem.sh/docs/actions/public/getBlockTransactionCount
- JSON-RPC Methods:
  - Calls [`eth_getBlockTransactionCountByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbynumber) for `blockNumber` & `blockTag`.
  - Calls [`eth_getBlockTransactionCountByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblocktransactioncountbyhash) for `blockHash`.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const count = await client.getBlockTransactionCount()
```

###### publicClient.getBytecode

(`args`) => `Promise`\<`GetCodeReturnType`\>

**Deprecated**

Use `getCode` instead.

###### publicClient.getChainId

() => `Promise`\<`number`\>

Returns the chain ID associated with the current network.

- Docs: https://viem.sh/docs/actions/public/getChainId
- JSON-RPC Methods: [`eth_chainId`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_chainid)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const chainId = await client.getChainId()
// 1
```

###### publicClient.getCode

(`args`) => `Promise`\<`GetCodeReturnType`\>

Retrieves the bytecode at an address.

- Docs: https://viem.sh/docs/contract/getCode
- JSON-RPC Methods: [`eth_getCode`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getcode)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getCode({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
})
```

###### publicClient.getContractEvents

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetContractEventsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs emitted by a contract.

- Docs: https://viem.sh/docs/actions/public/getContractEvents
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { wagmiAbi } from './abi'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getContractEvents(client, {
 address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
 abi: wagmiAbi,
 eventName: 'Transfer'
})
```

###### publicClient.getDelegation

(`args`) => `Promise`\<`GetDelegationReturnType`\>

Returns the address that an account has delegated to via EIP-7702.

- Docs: https://viem.sh/docs/actions/public/getDelegation

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const delegation = await client.getDelegation({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getEip712Domain

(`args`) => `Promise`\<`GetEip712DomainReturnType`\>

Reads the EIP-712 domain from a contract, based on the ERC-5267 specification.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const domain = await client.getEip712Domain({
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
})
// {
//   domain: {
//     name: 'ExampleContract',
//     version: '1',
//     chainId: 1,
//     verifyingContract: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
//   },
//   fields: '0x0f',
//   extensions: [],
// }
```

###### publicClient.getEnsAddress

(`args`) => `Promise`\<`GetEnsAddressReturnType`\>

Gets address for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAddress
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAddress = await client.getEnsAddress({
  name: normalize('wevm.eth'),
})
// '0xd2135CfB216b74109775236E36d4b433F1DF507B'
```

###### publicClient.getEnsAvatar

(`args`) => `Promise`\<`GetEnsAvatarReturnType`\>

Gets the avatar of an ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsAvatar
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls [`getEnsText`](https://viem.sh/docs/ens/actions/getEnsText) with `key` set to `'avatar'`.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensAvatar = await client.getEnsAvatar({
  name: normalize('wevm.eth'),
})
// 'https://ipfs.io/ipfs/Qma8mnp6xV3J2cRNf3mTth5C8nV11CAnceVinc3y8jSbio'
```

###### publicClient.getEnsName

(`args`) => `Promise`\<`GetEnsNameReturnType`\>

Gets primary name for specified address.

- Docs: https://viem.sh/docs/ens/actions/getEnsName
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `reverse(bytes)` on ENS Universal Resolver Contract to "reverse resolve" the address to the primary ENS name.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const ensName = await client.getEnsName({
  address: '0xd2135CfB216b74109775236E36d4b433F1DF507B',
})
// 'wevm.eth'
```

###### publicClient.getEnsResolver

(`args`) => `Promise`\<`` `0x${string}` ``\>

Gets resolver for ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `findResolver(bytes)` on ENS Universal Resolver Contract to retrieve the resolver of an ENS name.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const resolverAddress = await client.getEnsResolver({
  name: normalize('wevm.eth'),
})
// '0x4976fb03C32e5B8cfe2b6cCB31c09Ba78EBaBa41'
```

###### publicClient.getEnsText

(`args`) => `Promise`\<`GetEnsTextReturnType`\>

Gets a text record for specified ENS name.

- Docs: https://viem.sh/docs/ens/actions/getEnsResolver
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/ens

**Remarks**

Calls `resolve(bytes, bytes)` on ENS Universal Resolver Contract.

Since ENS names prohibit certain forbidden characters (e.g. underscore) and have other validation rules, you likely want to [normalize ENS names](https://docs.ens.domains/contract-api-reference/name-processing#normalising-names) with [UTS-46 normalization](https://unicode.org/reports/tr46) before passing them to `getEnsAddress`. You can use the built-in [`normalize`](https://viem.sh/docs/ens/utilities/normalize) function for this.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { normalize } from 'viem/ens'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const twitterRecord = await client.getEnsText({
  name: normalize('wevm.eth'),
  key: 'com.twitter',
})
// 'wevm_dev'
```

###### publicClient.getFeeHistory

(`args`) => `Promise`\<`GetFeeHistoryReturnType`\>

Returns a collection of historical gas information.

- Docs: https://viem.sh/docs/actions/public/getFeeHistory
- JSON-RPC Methods: [`eth_feeHistory`](https://docs.alchemy.com/reference/eth-feehistory)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const feeHistory = await client.getFeeHistory({
  blockCount: 4,
  rewardPercentiles: [25, 75],
})
```

###### publicClient.getFilterChanges

\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterChangesReturnType`\<`filterType`, `abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of logs or hashes based on a [Filter](/docs/glossary/terms#filter) since the last time it was called.

- Docs: https://viem.sh/docs/actions/public/getFilterChanges
- JSON-RPC Methods: [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges)

**Remarks**

A Filter can be created from the following actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createContractEventFilter`](https://viem.sh/docs/contract/createContractEventFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

Depending on the type of filter, the return value will be different:

- If the filter was created with `createContractEventFilter` or `createEventFilter`, it returns a list of logs.
- If the filter was created with `createPendingTransactionFilter`, it returns a list of transaction hashes.
- If the filter was created with `createBlockFilter`, it returns a list of block hashes.

**Examples**

```ts
// Blocks
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createBlockFilter()
const hashes = await client.getFilterChanges({ filter })
```

```ts
// Contract Events
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createContractEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  abi: parseAbi(['event Transfer(address indexed, address indexed, uint256)']),
  eventName: 'Transfer',
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Raw Events
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterChanges({ filter })
```

```ts
// Transactions
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createPendingTransactionFilter()
const hashes = await client.getFilterChanges({ filter })
```

###### publicClient.getFilterLogs

\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>(`args`) => `Promise`\<`GetFilterLogsReturnType`\<`abi`, `eventName`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs since the filter was created.

- Docs: https://viem.sh/docs/actions/public/getFilterLogs
- JSON-RPC Methods: [`eth_getFilterLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterlogs)

**Remarks**

`getFilterLogs` is only compatible with **event filters**.

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const filter = await client.createEventFilter({
  address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
  event: parseAbiItem('event Transfer(address indexed, address indexed, uint256)'),
})
const logs = await client.getFilterLogs({ filter })
```

###### publicClient.getGasPrice

() => `Promise`\<`bigint`\>

Returns the current price of gas (in wei).

- Docs: https://viem.sh/docs/actions/public/getGasPrice
- JSON-RPC Methods: [`eth_gasPrice`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gasprice)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const gasPrice = await client.getGasPrice()
```

###### publicClient.getLogs

\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>(`args?`) => `Promise`\<`GetLogsReturnType`\<`abiEvent`, `abiEvents`, `strict`, `fromBlock`, `toBlock`\>\>

Returns a list of event logs matching the provided parameters.

- Docs: https://viem.sh/docs/actions/public/getLogs
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/logs_event-logs
- JSON-RPC Methods: [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs)

**Example**

```ts
import { createPublicClient, http, parseAbiItem } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const logs = await client.getLogs()
```

###### publicClient.getProof

(`args`) => `Promise`\<`GetProofReturnType`\>

Returns the account and storage values of the specified account including the Merkle-proof.

- Docs: https://viem.sh/docs/actions/public/getProof
- JSON-RPC Methods:
  - Calls [`eth_getProof`](https://eips.ethereum.org/EIPS/eip-1186)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const block = await client.getProof({
 address: '0x...',
 storageKeys: ['0x...'],
})
```

###### publicClient.getStorageAt

(`args`) => `Promise`\<`GetStorageAtReturnType`\>

Returns the value from a storage slot at a given address.

- Docs: https://viem.sh/docs/contract/getStorageAt
- JSON-RPC Methods: [`eth_getStorageAt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getstorageat)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { getStorageAt } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const code = await client.getStorageAt({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  slot: toHex(0),
})
```

###### publicClient.getTransaction

\<`blockTag`\>(`args`) => `Promise`\<
  \| \{
  `accessList?`: `undefined`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId?`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"legacy"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity?`: `undefined`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice`: `bigint`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas?`: `undefined`;
  `maxPriorityFeePerGas?`: `undefined`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip2930"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip1559"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList?`: `undefined`;
  `blobVersionedHashes`: readonly `` `0x${string}` ``[];
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas`: `bigint`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip4844"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}
  \| \{
  `accessList`: `AccessList`;
  `authorizationList`: `SignedAuthorizationList`;
  `blobVersionedHashes?`: `undefined`;
  `blockHash`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `` `0x${string}` ``;
  `blockNumber`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `bigint`;
  `chainId`: `number`;
  `from`: `` `0x${string}` ``;
  `gas`: `bigint`;
  `gasPrice?`: `undefined`;
  `hash`: `` `0x${string}` ``;
  `input`: `` `0x${string}` ``;
  `maxFeePerBlobGas?`: `undefined`;
  `maxFeePerGas`: `bigint`;
  `maxPriorityFeePerGas`: `bigint`;
  `nonce`: `number`;
  `r`: `` `0x${string}` ``;
  `s`: `` `0x${string}` ``;
  `to`: `` `0x${string}` `` \| `null`;
  `transactionIndex`: `blockTag` *extends* `"pending"` ? `true` : `false` *extends* `true` ? `null` : `number`;
  `type`: `"eip7702"`;
  `typeHex`: `` `0x${string}` `` \| `null`;
  `v`: `bigint`;
  `value`: `bigint`;
  `yParity`: `number`;
\}\>

Returns information about a [Transaction](https://viem.sh/docs/glossary/terms#transaction) given a hash or block identifier.

- Docs: https://viem.sh/docs/actions/public/getTransaction
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionByHash`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionByHash)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transaction = await client.getTransaction({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionConfirmations

(`args`) => `Promise`\<`bigint`\>

Returns the number of blocks passed (confirmations) since the transaction was processed on a block.

- Docs: https://viem.sh/docs/actions/public/getTransactionConfirmations
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionConfirmations`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionConfirmations)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const confirmations = await client.getTransactionConfirmations({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.getTransactionCount

(`args`) => `Promise`\<`number`\>

Returns the number of [Transactions](https://viem.sh/docs/glossary/terms#transaction) an Account has broadcast / sent.

- Docs: https://viem.sh/docs/actions/public/getTransactionCount
- JSON-RPC Methods: [`eth_getTransactionCount`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_gettransactioncount)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionCount = await client.getTransactionCount({
  address: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.getTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt) given a [Transaction](https://viem.sh/docs/glossary/terms#transaction) hash.

- Docs: https://viem.sh/docs/actions/public/getTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_fetching-transactions
- JSON-RPC Methods: [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.getTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.key

`string`

A key for the client.

###### publicClient.multicall

\<`contracts`, `allowFailure`\>(`args`) => `Promise`\<`MulticallReturnType`\<`contracts`, `allowFailure`\>\>

Similar to [`readContract`](https://viem.sh/docs/contract/readContract), but batches up multiple functions on a contract in a single RPC call via the [`multicall3` contract](https://github.com/mds1/multicall).

- Docs: https://viem.sh/docs/contract/multicall

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const abi = parseAbi([
  'function balanceOf(address) view returns (uint256)',
  'function totalSupply() view returns (uint256)',
])
const result = await client.multicall({
  contracts: [
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'balanceOf',
      args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
    },
    {
      address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
      abi,
      functionName: 'totalSupply',
    },
  ],
})
// [{ result: 424122n, status: 'success' }, { result: 1000000n, status: 'success' }]
```

###### publicClient.name

`string`

A name for the client.

###### publicClient.pollingInterval

`number`

Frequency (in ms) for polling enabled actions & events. Defaults to 4_000 milliseconds.

###### publicClient.prepareTransactionRequest

\<`request`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<\{ \[K in string \| number \| symbol\]: (UnionRequiredBy\<(...) & (...), ParameterTypeToParameters\<(...)\>\> & (unknown extends (...)\[(...)\] ? \{\} : Pick\<(...), (...)\>))\[K\] \}\>

Prepares a transaction request for signing.

- Docs: https://viem.sh/docs/actions/wallet/prepareTransactionRequest

**Examples**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

```ts
// Account Hoisting
import { createWalletClient, http } from 'viem'
import { privateKeyToAccount } from 'viem/accounts'
import { mainnet } from 'viem/chains'

const client = createWalletClient({
  account: privateKeyToAccount('0x…'),
  chain: mainnet,
  transport: custom(window.ethereum),
})
const request = await client.prepareTransactionRequest({
  to: '0x0000000000000000000000000000000000000000',
  value: 1n,
})
```

###### publicClient.readContract

\<`abi`, `functionName`, `args`\>(`args`) => `Promise`\<`ReadContractReturnType`\<`abi`, `functionName`, `args`\>\>

Calls a read-only function on a contract, and returns the response.

- Docs: https://viem.sh/docs/contract/readContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_reading-contracts

**Remarks**

A "read-only" function (constant function) on a Solidity contract is denoted by a `view` or `pure` keyword. They can only read the state of the contract, and cannot make any changes to it. Since read-only methods do not change the state of the contract, they do not require any gas to be executed, and can be called by any user without the need to pay for gas.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'
import { readContract } from 'viem/contract'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.readContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function balanceOf(address) view returns (uint256)']),
  functionName: 'balanceOf',
  args: ['0xA0Cf798816D4b9b9866b5330EEa46a18382f251e'],
})
// 424122n
```

###### publicClient.request

`EIP1193RequestFn`\<`PublicRpcSchema`\>

Request function wrapped with friendly error handling

###### publicClient.sendRawTransaction

(`args`) => `Promise`\<`` `0x${string}` ``\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransaction
- JSON-RPC Method: [`eth_sendRawTransaction`](https://ethereum.github.io/execution-apis/api-documentation/)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransaction } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const hash = await client.sendRawTransaction({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.sendRawTransactionSync

(`args`) => `Promise`\<`TransactionReceipt`\>

Sends a **signed** transaction to the network

- Docs: https://viem.sh/docs/actions/wallet/sendRawTransactionSync
- JSON-RPC Method: [`eth_sendRawTransactionSync`](https://eips.ethereum.org/EIPS/eip-7966)

**Example**

```ts
import { createWalletClient, custom } from 'viem'
import { mainnet } from 'viem/chains'
import { sendRawTransactionSync } from 'viem/wallet'

const client = createWalletClient({
  chain: mainnet,
  transport: custom(window.ethereum),
})

const receipt = await client.sendRawTransactionSync({
  serializedTransaction: '0x02f850018203118080825208808080c080a04012522854168b27e5dc3d5839bab5e6b39e1a0ffd343901ce1622e3d64b48f1a04e00902ae0502c4728cbf12156290df99c3ed7de85b1dbfe20b5c36931733a33'
})
```

###### publicClient.simulate

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

**Deprecated**

Use `simulateBlocks` instead.

###### publicClient.simulateBlocks

\<`calls`\>(`args`) => `Promise`\<`SimulateBlocksReturnType`\<`calls`\>\>

Simulates a set of calls on block(s) with optional block and state overrides.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateBlocks({
  blocks: [{
    blockOverrides: {
      number: 69420n,
    },
    calls: [{
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        data: '0xdeadbeef',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      },
      {
        account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
        to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
        value: parseEther('1'),
      },
    }],
    stateOverrides: [{
      address: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
      balance: parseEther('10'),
    }],
  }]
})
```

###### publicClient.simulateCalls

\<`calls`\>(`args`) => `Promise`\<`SimulateCallsReturnType`\<`calls`\>\>

Simulates a set of calls.

**Example**

```ts
import { createPublicClient, http, parseEther } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})

const result = await client.simulateCalls({
  account: '0x5a0b54d5dc17e482fe8b0bdca5320161b95fb929',
  calls: [{
    {
      data: '0xdeadbeef',
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
    },
    {
      to: '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',
      value: parseEther('1'),
    },
  ]
})
```

###### publicClient.simulateContract

\<`abi`, `functionName`, `args`, `chainOverride`, `accountOverride`\>(`args`) => `Promise`\<`SimulateContractReturnType`\<`abi`, `functionName`, `args`, `Chain` \| `undefined`, `Account` \| `undefined`, `chainOverride`, `accountOverride`\>\>

Simulates/validates a contract interaction. This is useful for retrieving **return data** and **revert reasons** of contract write functions.

- Docs: https://viem.sh/docs/contract/simulateContract
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/contracts_writing-to-contracts

**Remarks**

This function does not require gas to execute and _**does not**_ change the state of the blockchain. It is almost identical to [`readContract`](https://viem.sh/docs/contract/readContract), but also supports contract write functions.

Internally, uses a [Public Client](https://viem.sh/docs/clients/public) to call the [`call` action](https://viem.sh/docs/actions/public/call) with [ABI-encoded `data`](https://viem.sh/docs/contract/encodeFunctionData).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const result = await client.simulateContract({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['function mint(uint32) view returns (uint32)']),
  functionName: 'mint',
  args: ['69420'],
  account: '0xA0Cf798816D4b9b9866b5330EEa46a18382f251e',
})
```

###### publicClient.transport

`TransportConfig`\<`string`, `EIP1193RequestFn`\> & `Record`\<`string`, `any`\>

The RPC transport

###### publicClient.type

`string`

The type of client.

###### publicClient.uid

`string`

A unique ID for the client.

###### publicClient.uninstallFilter

(`args`) => `Promise`\<`boolean`\>

Destroys a Filter that was created from one of the following Actions:

- [`createBlockFilter`](https://viem.sh/docs/actions/public/createBlockFilter)
- [`createEventFilter`](https://viem.sh/docs/actions/public/createEventFilter)
- [`createPendingTransactionFilter`](https://viem.sh/docs/actions/public/createPendingTransactionFilter)

- Docs: https://viem.sh/docs/actions/public/uninstallFilter
- JSON-RPC Methods: [`eth_uninstallFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_uninstallFilter)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'
import { createPendingTransactionFilter, uninstallFilter } from 'viem/public'

const filter = await client.createPendingTransactionFilter()
const uninstalled = await client.uninstallFilter({ filter })
// true
```

###### publicClient.verifyHash

(`args`) => `Promise`\<`boolean`\>

Verify that a hash was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyHash](https://viem.sh/docs/actions/public/verifyHash)

###### publicClient.verifyMessage

(`args`) => `Promise`\<`boolean`\>

Verify that a message was signed by the provided address.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/actions/public/verifyMessage](https://viem.sh/docs/actions/public/verifyMessage)

###### publicClient.verifySiweMessage

(`args`) => `Promise`\<`boolean`\>

Verifies [EIP-4361](https://eips.ethereum.org/EIPS/eip-4361) formatted message was signed.

Compatible with Smart Contract Accounts & Externally Owned Accounts via [ERC-6492](https://eips.ethereum.org/EIPS/eip-6492).

- Docs [https://viem.sh/docs/siwe/actions/verifySiweMessage](https://viem.sh/docs/siwe/actions/verifySiweMessage)

###### publicClient.verifyTypedData

(`args`) => `Promise`\<`boolean`\>

Verify that typed data was signed by the provided address.

- Docs [https://viem.sh/docs/actions/public/verifyTypedData](https://viem.sh/docs/actions/public/verifyTypedData)

###### publicClient.waitForTransactionReceipt

(`args`) => `Promise`\<`TransactionReceipt`\>

Waits for the [Transaction](https://viem.sh/docs/glossary/terms#transaction) to be included on a [Block](https://viem.sh/docs/glossary/terms#block) (one confirmation), and then returns the [Transaction Receipt](https://viem.sh/docs/glossary/terms#transaction-receipt). If the Transaction reverts, then the action will throw an error.

- Docs: https://viem.sh/docs/actions/public/waitForTransactionReceipt
- Example: https://stackblitz.com/github/wevm/viem/tree/main/examples/transactions_sending-transactions
- JSON-RPC Methods:
  - Polls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt) on each block until it has been processed.
  - If a Transaction has been replaced:
    - Calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getblockbynumber) and extracts the transactions
    - Checks if one of the Transactions is a replacement
    - If so, calls [`eth_getTransactionReceipt`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getTransactionReceipt).

**Remarks**

The `waitForTransactionReceipt` action additionally supports Replacement detection (e.g. sped up Transactions).

Transactions can be replaced when a user modifies their transaction in their wallet (to speed up or cancel). Transactions are replaced when they are sent from the same nonce.

There are 3 types of Transaction Replacement reasons:

- `repriced`: The gas price has been modified (e.g. different `maxFeePerGas`)
- `cancelled`: The Transaction has been cancelled (e.g. `value === 0n`)
- `replaced`: The Transaction has been replaced (e.g. different `value` or `data`)

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const transactionReceipt = await client.waitForTransactionReceipt({
  hash: '0x4ca7ee652d57678f26e887c149ab0735f41de37bcad58c9f6d3ed5824f15b74d',
})
```

###### publicClient.watchBlockNumber

(`args`) => `WatchBlockNumberReturnType`

Watches and returns incoming block numbers.

- Docs: https://viem.sh/docs/actions/public/watchBlockNumber
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_blockNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_blocknumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlockNumber({
  onBlockNumber: (blockNumber) => console.log(blockNumber),
})
```

###### publicClient.watchBlocks

\<`includeTransactions`, `blockTag`\>(`args`) => `WatchBlocksReturnType`

Watches and returns information for incoming blocks.

- Docs: https://viem.sh/docs/actions/public/watchBlocks
- Examples: https://stackblitz.com/github/wevm/viem/tree/main/examples/blocks_watching-blocks
- JSON-RPC Methods:
  - When `poll: true`, calls [`eth_getBlockByNumber`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getBlockByNumber) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newHeads"` event.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchBlocks({
  onBlock: (block) => console.log(block),
})
```

###### publicClient.watchContractEvent

\<`abi`, `eventName`, `strict`\>(`args`) => `WatchContractEventReturnType`

Watches and returns emitted contract event logs.

- Docs: https://viem.sh/docs/contract/watchContractEvent

**Remarks**

This Action will batch up all the event logs found within the [`pollingInterval`](https://viem.sh/docs/contract/watchContractEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/contract/watchContractEvent#onLogs).

`watchContractEvent` will attempt to create an [Event Filter](https://viem.sh/docs/contract/createContractEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchContractEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http, parseAbi } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchContractEvent({
  address: '0xFBA3912Ca04dd458c843e2EE08967fC04f3579c2',
  abi: parseAbi(['event Transfer(address indexed from, address indexed to, uint256 value)']),
  eventName: 'Transfer',
  args: { from: '0xc961145a54C96E3aE9bAA048c4F4D6b04C13916b' },
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchEvent

\<`abiEvent`, `abiEvents`, `strict`\>(`args`) => `WatchEventReturnType`

Watches and returns emitted [Event Logs](https://viem.sh/docs/glossary/terms#event-log).

- Docs: https://viem.sh/docs/actions/public/watchEvent
- JSON-RPC Methods:
  - **RPC Provider supports `eth_newFilter`:**
    - Calls [`eth_newFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newfilter) to create a filter (called on initialize).
    - On a polling interval, it will call [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getfilterchanges).
  - **RPC Provider does not support `eth_newFilter`:**
    - Calls [`eth_getLogs`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getlogs) for each block between the polling interval.

**Remarks**

This Action will batch up all the Event Logs found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchEvent#pollinginterval-optional), and invoke them via [`onLogs`](https://viem.sh/docs/actions/public/watchEvent#onLogs).

`watchEvent` will attempt to create an [Event Filter](https://viem.sh/docs/actions/public/createEventFilter) and listen to changes to the Filter per polling interval, however, if the RPC Provider does not support Filters (e.g. `eth_newFilter`), then `watchEvent` will fall back to using [`getLogs`](https://viem.sh/docs/actions/public/getLogs) instead.

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = client.watchEvent({
  onLogs: (logs) => console.log(logs),
})
```

###### publicClient.watchPendingTransactions

(`args`) => `WatchPendingTransactionsReturnType`

Watches and returns pending transaction hashes.

- Docs: https://viem.sh/docs/actions/public/watchPendingTransactions
- JSON-RPC Methods:
  - When `poll: true`
    - Calls [`eth_newPendingTransactionFilter`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_newpendingtransactionfilter) to initialize the filter.
    - Calls [`eth_getFilterChanges`](https://ethereum.org/en/developers/docs/apis/json-rpc/#eth_getFilterChanges) on a polling interval.
  - When `poll: false` & WebSocket Transport, uses a WebSocket subscription via [`eth_subscribe`](https://docs.alchemy.com/reference/eth-subscribe-polygon) and the `"newPendingTransactions"` event.

**Remarks**

This Action will batch up all the pending transactions found within the [`pollingInterval`](https://viem.sh/docs/actions/public/watchPendingTransactions#pollinginterval-optional), and invoke them via [`onTransactions`](https://viem.sh/docs/actions/public/watchPendingTransactions#ontransactions).

**Example**

```ts
import { createPublicClient, http } from 'viem'
import { mainnet } from 'viem/chains'

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
})
const unwatch = await client.watchPendingTransactions({
  onTransactions: (hashes) => console.log(hashes),
})
```

###### tokenAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

### isWhitelisted()

```ts
isWhitelisted: (__namedParameters) => Promise<boolean>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

### isWhitelistedAQ()

```ts
isWhitelistedAQ: (__namedParameters) => Promise<boolean>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<`boolean`\>

### pauseStrategyTx()

```ts
pauseStrategyTx: (__namedParameters) => Promise<PauseDcaStrategyTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### strategyId

`string`

#### Returns

`Promise`\<[`PauseDcaStrategyTransactionInfo`](../../sdk-common/type-aliases/PauseDcaStrategyTransactionInfo.md)\>

### resumeStrategyTx()

```ts
resumeStrategyTx: (__namedParameters) => Promise<ResumeDcaStrategyTransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### inAssetFeed

`` `0x${string}` ``

###### order

[`IArmadaDcaOrder`](../../sdk-common/interfaces/IArmadaDcaOrder.md)

###### outAssetFeed

`` `0x${string}` ``

###### strategyId

`string`

#### Returns

`Promise`\<[`ResumeDcaStrategyTransactionInfo`](../../sdk-common/type-aliases/ResumeDcaStrategyTransactionInfo.md)\>

### revokeContractSpecificRole()

```ts
revokeContractSpecificRole: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### contractAddress

`string`

###### role

[`ContractSpecificRoleName`](../../sdk-common/enumerations/ContractSpecificRoleName.md)

###### targetAddress

`string`

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setArkDepositCap()

```ts
setArkDepositCap: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### arkAddress

`string`

###### cap

`string`

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### token

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setArkMaxDepositPercentageOfTVL()

```ts
setArkMaxDepositPercentageOfTVL: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### arkAddress

`string`

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### maxDepositPercentage

`number`

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setFleetDepositCap()

```ts
setFleetDepositCap: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### cap

`string`

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### token

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setMinimumBufferBalance()

```ts
setMinimumBufferBalance: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### chainInfo

[`IChainInfo`](../../sdk-common/interfaces/IChainInfo.md)

###### fleetAddress

`string`

###### minimumBufferBalance

`string`

###### token

[`ITokenStanalone`](../../sdk-common/interfaces/ITokenStanalone.md)

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setWhitelistedAQTx()

```ts
setWhitelistedAQTx: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### allowed

`boolean`

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setWhitelistedBatchAQTx()

```ts
setWhitelistedBatchAQTx: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### allowed

`boolean`[]

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### targetAddresses

`` `0x${string}` ``[]

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setWhitelistedBatchTx()

```ts
setWhitelistedBatchTx: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### allowed

`boolean`[]

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddresses

`` `0x${string}` ``[]

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>

### setWhitelistedTx()

```ts
setWhitelistedTx: (__namedParameters) => Promise<TransactionInfo>;
```

#### Parameters

##### \_\_namedParameters

###### allowed

`boolean`

###### chainId

[`ChainId`](../../sdk-common/type-aliases/ChainId.md)

###### fleetCommanderAddress

`` `0x${string}` ``

###### targetAddress

`` `0x${string}` ``

#### Returns

`Promise`\<[`TransactionInfo`](../../sdk-common/interfaces/TransactionInfo.md)\>
