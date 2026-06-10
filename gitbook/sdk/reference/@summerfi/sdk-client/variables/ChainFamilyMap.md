# Variable: ChainFamilyMap

```ts
const ChainFamilyMap: object;
```

Defined in: [sdk/sdk-common/src/common/implementation/ChainFamilies.ts:67](https://github.com/OasisDEX/summerfi-monorepo/blob/1402deca577ac262b618bb0671f1c1173a1fd152/sdk/sdk-common/src/common/implementation/ChainFamilies.ts#L67)

## Type Declaration

### Arbitrum

```ts
Arbitrum: Record<"ArbitrumOne", ChainInfo> = ArbitrumFamily;
```

### Base

```ts
Base: Record<"Base", ChainInfo> = BaseFamily;
```

### Ethereum

```ts
Ethereum: Record<"Mainnet", ChainInfo> = EthereumFamily;
```

### Hyperliquid

```ts
Hyperliquid: Record<"Hyperliquid", ChainInfo> = HyperliquidFamily;
```

### Optimism

```ts
Optimism: Record<"Optimism", ChainInfo> = OptimismFamily;
```

### Sonic

```ts
Sonic: Record<"Sonic", ChainInfo> = SonicFamily;
```

## Description

A map of chain family names to chain families. It can be used to
             retrieve the ChainId of a chain family + chain combination
