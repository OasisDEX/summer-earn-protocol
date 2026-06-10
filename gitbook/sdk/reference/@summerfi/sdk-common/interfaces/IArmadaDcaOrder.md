# Interface: IArmadaDcaOrder

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:6](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L6)

## Properties

### allowedVaultsRoot

```ts
allowedVaultsRoot: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L25)

***

### amount

```ts
amount: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L14)

***

### cancelledAt?

```ts
optional cancelledAt: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:35](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L35)

***

### chainId

```ts
chainId: ChainId;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L11)

***

### createdAt

```ts
createdAt: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:33](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L33)

***

### deadlineUnixTimestamp?

```ts
optional deadlineUnixTimestamp: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:20](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L20)

Unix timestamp after which the order stops executing (optional — absent means run until maxTrades is reached)

***

### ensoRouterAddress

```ts
ensoRouterAddress: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:30](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L30)

***

### fromVault

```ts
fromVault: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L12)

***

### fromVaultProof

```ts
fromVaultProof: `0x${string}`[];
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:26](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L26)

***

### id

```ts
id: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:7](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L7)

***

### intervalSeconds

```ts
intervalSeconds: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L16)

***

### maxTrades

```ts
maxTrades: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:22](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L22)

Maximum number of trades to execute before the order completes

***

### neverBuyAbove?

```ts
optional neverBuyAbove: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:38](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L38)

Price ceiling — skip execution if the fromVault token price is above this value

***

### neverSellBelow?

```ts
optional neverSellBelow: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:40](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L40)

Price floor — skip execution if the toVault token price is below this value

***

### nextExecutionAtUnixTimestamp

```ts
nextExecutionAtUnixTimestamp: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L18)

Unix timestamp of the next scheduled execution

***

### orderId

```ts
orderId: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L9)

External order identifier provided by the caller (distinct from the DB row id)

***

### pausedAt?

```ts
optional pausedAt: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:36](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L36)

***

### signature

```ts
signature: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:29](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L29)

***

### slippage

```ts
slippage: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L15)

***

### status

```ts
status: ArmadaDcaOrderStatusEnum;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:32](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L32)

***

### swapCalldata

```ts
swapCalldata: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:28](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L28)

***

### toVault

```ts
toVault: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L13)

***

### toVaultProof

```ts
toVaultProof: `0x${string}`[];
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:27](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L27)

***

### tradesExecuted

```ts
tradesExecuted: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L24)

Number of trades that have been executed so far

***

### updatedAt

```ts
updatedAt: number;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:34](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L34)

***

### userAddress

```ts
userAddress: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L10)

***

### verifyingContractAddress

```ts
verifyingContractAddress: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts:31](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaOrder.ts#L31)
