# Interface: IArmadaDcaStrategyConfig

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:8](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L8)

## Name

IArmadaDcaStrategyConfig

## Description

Serializable representation of the IDCAStrategyManager.StrategyConfig calldata struct.
             Numeric fields are raw uint256 values encoded as base-10 strings.

## Properties

### endDate

```ts
endDate: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:24](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L24)

***

### inAsset

```ts
inAsset: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:13](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L13)

***

### inAssetFeed

```ts
inAssetFeed: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:15](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L15)

***

### interval

```ts
interval: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:18](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L18)

***

### maxPrice

```ts
maxPrice: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:21](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L21)

Price ceiling in oracle units. Maps to the UI concept of never buy above.

***

### maxTrades

```ts
maxTrades: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:25](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L25)

***

### minPrice

```ts
minPrice: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:23](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L23)

Price floor in oracle units. Maps to the UI concept of never sell below.

***

### outAsset

```ts
outAsset: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:14](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L14)

***

### outAssetFeed

```ts
outAssetFeed: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:16](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L16)

***

### owner

```ts
owner: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:10](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L10)

***

### slippageBps

```ts
slippageBps: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:19](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L19)

***

### sourceVault

```ts
sourceVault: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:11](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L11)

***

### strategyId

```ts
strategyId: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:9](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L9)

***

### targetVault

```ts
targetVault: `0x${string}`;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:12](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L12)

***

### tradeAmount

```ts
tradeAmount: string;
```

Defined in: [sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts:17](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/interfaces/IArmadaDcaStrategyConfig.ts#L17)
