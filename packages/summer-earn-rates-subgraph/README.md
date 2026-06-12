# Summer Earn Rates Subgraph

This subgraph indexes earn rates (APR/APY) and TVL for DeFi protocols across mainnet, Arbitrum,
Optimism, Base, Sonic, and HyperLiquid. It is deployed via Goldsky and queried by the Summer.fi
frontend and backend to show yield data for each fleet.

## Key source files

- `src/config/protocolConfig.ts` — `ProtocolConfig` class with one `init<Network>()` method per
  chain (e.g. `initMainnet()`, `initArbitrum()`, `initBase()`, `initSonic()`, `initHyperLiquid()`).
  Every tracked protocol/product is registered here.
- `src/products/` — 22 `Product` subclasses (e.g. `AaveV3Product`, `HypurrProduct`,
  `SecuritizeDailyAccrualProduct`). Each implements `getRate`, `getRewardsRates`, and `getTvl`.
- `src/constants/addresses.ts` — token/contract addresses, branched on `dataSource.network()` using
  graph-node slugs (`arbitrum-one`, `sonic-mainnet`, `hyperliquid` or `hyperevm`). Throws
  `Unsupported network` for unknown slugs.
- `src/utils/chainId.ts` — `getChainIdByNetworkName` maps graph-node slugs to chain IDs. Unknown
  slugs throw and break product IDs.
- `config/<network>.json` — per-network entry point address, start block, block interval, and
  grafting fields (`grafting-base`, `grafting-block`, `enable-grafting`).

## Build and deploy commands

All commands are network-scoped. There is no bare `build` or `deploy` script.

```bash
# Generate AssemblyScript types from the schema and ABIs
pnpm codegen

# Build for a specific network (runs mustache + codegen + graph build)
pnpm build:mainnet
pnpm build:arbitrum
pnpm build:base
pnpm build:optimism
pnpm build:sonic
pnpm build:hyperliquid

# Deploy to Goldsky (requires GOLDSKY_TOKEN in ../../.env)
pnpm deploy:mainnet
pnpm deploy:arbitrum
pnpm deploy:base
pnpm deploy:optimism
pnpm deploy:sonic
pnpm deploy:hyperliquid

# Deploy mainnet + sonic + arbitrum in sequence
pnpm deploy:all
```

Each `prepare:<network>` script renders `subgraph.template.yaml` through Mustache using
`config/<network>.json` to produce `subgraph.yaml`. Bump `version` in `package.json` before
deploying; Goldsky uses `$npm_package_version` as the deployment tag.

## Adding a new protocol/pool

1. Add any new token addresses to `src/constants/addresses.ts` under the correct
   `dataSource.network()` branch.
2. If no existing `Product` subclass fits, create one under `src/products/` extending `Product`.
3. Register a `Protocol` instance (with one or more product instances) inside the appropriate
   `init<Network>()` method in `src/config/protocolConfig.ts`.
4. The product ID is `${groupName}-${tokenAddress}-${poolAddress}-${chainId}` (built in `Product`
   constructor). It must match the ID format used by `summer-earn-protocol-subgraph` or rate
   correlation will silently miss.
5. Set `grafting-base` and `grafting-block` in `config/<network>.json` to avoid a full resync, then
   redeploy.

## Cross-package connections

**Consumes:**

- No TypeScript packages from this monorepo are imported at runtime. The subgraph is
  AssemblyScript/The Graph only.

**Consumed by:**

- `packages/summer-earn-protocol-subgraph` — correlates its `Ark` entities to rate data by
  constructing the same product ID string (`protocol-asset-pool-chainId`). If the ID built here
  diverges from the one built there, the join silently returns no rate data.
- Backend and frontend packages query the deployed Goldsky endpoints directly by URL; no TypeScript
  exports are shared.

**Agent gotchas:**

- `src/config/protocolConfig.ts`, `src/constants/addresses.ts`, and `src/utils/chainId.ts` are all
  hand-maintained and must be updated together when adding a chain or product.
- Graph-node network slugs differ from repo chain names: use `arbitrum-one` (not `arbitrum`),
  `sonic-mainnet` (not `sonic`), and either `hyperliquid` or `hyperevm` for HyperLiquid.
- `grafting-base` (Qm hash) and `grafting-block` in each `config/<network>.json` become stale after
  a redeployment that changes the schema or data sources; refresh them or set
  `enable-grafting: false` to force a full resync.

## Documentation

GitBook: [Rates Subgraph](../../gitbook/data/rates-subgraph.md)
