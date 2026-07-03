# summer-earn-dca-subgraph

The-Graph / Goldsky subgraph that indexes `DCAStrategyManager` events (`StrategyCreated`,
`StrategyEdited`, `StrategyPaused`, `StrategyResumed`, `StrategyCancelled`, `StrategyCompleted`,
`ExecutionCompleted`) on Base and Ethereum mainnet, and tracks Chainlink price feeds (USDC/ETH
bootstrap proxies plus any user-supplied feed pair) via event-driven `ChainlinkProxy` /
`ChainlinkAggregator` dynamic templates. Goldsky slugs: `summer-dca-base` (Base) and `summer-dca`
(mainnet).

## Key entities and source files

- `schema.graphql` — `User`, `Strategy`, `Execution`, `PriceFeed`, `PriceRound`,
  `AggregatorRotation` entities.
- `src/mappings/dcaStrategyManager.ts` — DCA event handlers; also handles `StrategyCancelled`;
  derives `COMPLETED` status locally as a defensive backup
  (`tradesExecuted >= maxTrades || blockTimestamp >= endDate`) in addition to the explicit
  `handleStrategyCompleted` handler.
- `src/mappings/chainlinkProxy.ts` — `handleProxyOnce` (kind: once block handler that resolves the
  current aggregator impl via `proxy.aggregator()`) and `handleAggregatorConfirmed` (tracks impl
  rotations).
- `src/mappings/chainlinkAggregator.ts` — `handleAnswerUpdated`; writes `PriceRound` records keyed
  by proxy address + roundId.
- `abis/DCAStrategyManager.json` — hand-pinned ABI; must be regenerated from the Foundry artifact
  after any contract interface change.
- `config/{base,mainnet}.json` — per-chain `dca-strategy-manager-address`,
  `dca-strategy-manager-start-block`, `feed-start-block` (~14 days earlier), and Chainlink **proxy**
  addresses (`usdc-feed-proxy`, `eth-feed-proxy`). Never put aggregator impl addresses here.

## Build and deploy commands

All commands are defined in `package.json`:

```
# Build for a specific chain (renders subgraph.yaml from template, then codegen + build)
pnpm run build:base
pnpm run build:mainnet

# Deploy via Goldsky CLI (requires .env at repo root with GOLDSKY credentials)
pnpm run deploy:base       # slug: summer-dca-base/<version>
pnpm run deploy:mainnet    # slug: summer-dca/<version>
pnpm run deploy:all        # deploys both chains sequentially
```

## Cross-package connections

**Consumes:**

- `config/{base,mainnet}.json` — hand-maintained per chain; values are placeholders until the
  contract is deployed on that chain.
- `abis/DCAStrategyManager.json` — hand-pinned from
  `packages/core-contracts/out/DCAStrategyManager.sol/DCAStrategyManager.json`; regenerate with
  `jq '.abi' <artifact> > abis/DCAStrategyManager.json` after any DCA contract interface change.
- `packages/core-contracts/src/contracts/DCA/CLAUDE.md` — canonical protocol rules; read before
  modifying handlers.

**Consumed by:**

- `packages/summer-earn-dca-app` — `src/config/chains.ts` points at the `summer-dca-base` Goldsky
  slug via a staging proxy.
- The DCA keeper (`packages/core-contracts/scripts/dca-keeper`) relies on `Strategy` and `Execution`
  entities from this subgraph.

**Agent gotchas:**

- `CLAUDE.md` in this package must be updated in the same commit as any logic change, with a
  sign-off line appended to the Sign-off block.
- `COMPLETED` status is derived in the handler
  (`tradesExecuted >= maxTrades || blockTimestamp >= endDate`), not from a contract event — schema
  consumers rely on this derived field.
- Config must contain Chainlink **proxy** addresses only; the `handleProxyOnce` block handler
  resolves the current aggregator impl on-chain. Using impl addresses in config will break indexing
  silently.
- Adding a new chain requires a new `config/<chain>.json`, new `build:<chain>` / `deploy:<chain>`
  scripts in `package.json`, and a CLAUDE.md sign-off in the same commit.
- The ABI is not generated automatically; a contract interface change will silently break codegen
  and handlers until `abis/DCAStrategyManager.json` is regenerated.

## Documentation

GitBook: [DCA Subgraph](../../gitbook/data/dca-subgraph.md) ·
[DCA Strategies concept](../../gitbook/concepts/dca.md)
