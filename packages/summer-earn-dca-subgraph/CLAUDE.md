# DCA subgraph

## Protocol

This file is meta-Claude memory. **Update it in the same commit as any
logic or design change here**, and add a line to the Sign-off block at the
bottom. The canonical protocol + DRY rules live in the
[contract CLAUDE.md](../core-contracts/src/contracts/DCA/CLAUDE.md); read it
first.

Siblings: [contract](../core-contracts/src/contracts/DCA/CLAUDE.md) ·
[keeper](../core-contracts/scripts/dca-keeper/CLAUDE.md) ·
[app](../summer-earn-dca-app/CLAUDE.md).

---

Goldsky subgraph indexing `DCAStrategyManager` events on Base. Slug:
`summer-dca-base`. Fronted by the staging proxy
`https://subgraph.staging.oasisapp.dev/summer-dca-base`.

## Files

- `schema.graphql` — `User`, `Strategy`, `Execution`, `PriceFeed`,
  `PriceRound`, `AggregatorRotation` entities. The wire format the
  [FE](../summer-earn-dca-app/CLAUDE.md) and the
  [keeper](../core-contracts/scripts/dca-keeper/CLAUDE.md) consume.
- `subgraph.template.yaml` — manifest with `{{network}}` /
  `{{dca-strategy-manager-address}}` placeholders; renders to `subgraph.yaml`
  per chain via `build:base`.
- `config/*.json` — per-chain start-block + contract address, plus
  `feed-start-block` (~14d before the manager) and **just the proxy
  addresses** for the bootstrap feeds (`usdc-feed-proxy`, `eth-feed-proxy`).
  No impl addresses anywhere — the subgraph resolves them itself at the
  first block via a `kind: once` block handler.
- `src/mappings/dcaStrategyManager.ts` — DCA event handlers; also calls
  `registerFeed` on create/edit, which just spins up a `ChainlinkProxy`
  template. The template's `handleProxyOnce` does the rest.
- `src/mappings/chainlinkProxy.ts` — two handlers shared by both the
  static bootstrap proxy dataSources and the dynamic `ChainlinkProxy`
  template:
  - `handleProxyOnce` (`kind: once` block handler) — fires on the
    dataSource's first block. Reads `proxy.aggregator()`, seeds the
    `PriceFeed` entity, and creates a `ChainlinkAggregator` template
    instance with the proxy address pinned in `DataSourceContext`.
    For static bootstrap dataSources the "first block" is
    `feed-start-block` ⇒ the aggregator template gets the full ~14d
    backfill. For the dynamic `ChainlinkProxy` template it's the
    strategy-create block ⇒ forward-only indexing for user feeds.
  - `handleAggregatorConfirmed` — Chainlink rotated the impl behind a
    proxy. Register a new `ChainlinkAggregator` template for `latest`,
    update `PriceFeed.aggregator`, log an `AggregatorRotation`.
- `src/mappings/chainlinkAggregator.ts` — `handleAnswerUpdated` for the
  dynamic `ChainlinkAggregator` template. Reads the proxy address from
  `dataSource.context()`, writes a `PriceRound` keyed by proxy + roundId.
- `src/common/{constants,initializers}.ts` — `StrategyStatus` literals,
  `getOrCreateUser`, `loadStrategyOrWarn`, `getOrCreatePriceFeedWithImpl`,
  `registerFeed`.
- `abis/DCAStrategyManager.json` — pinned ABI; **regenerate** from the
  Foundry artifact after any contract interface change (see
  [contract CLAUDE.md](../core-contracts/src/contracts/DCA/CLAUDE.md)).
- `abis/AggregatorProxy.json` — minimal Chainlink proxy ABI:
  `aggregator()`, `decimals()`, `description()`, events
  `AggregatorProposed` + `AggregatorConfirmed`.
- `abis/AggregatorV3Interface.json` — minimal Chainlink impl ABI:
  `decimals()`, `description()`, event `AnswerUpdated`. No
  `latestRoundData` — we no longer poll.

## Invariants

- **`StrategyConfig` no longer carries `strategyId`** — the subgraph reads
  `event.params.strategyId` for the entity key and never reads
  `event.params.config.strategyId` (it doesn't exist). Tuple has 14 fields.
- **Status derivation is local** in `updateStrategyStatus()` —
  `tradesExecuted.ge(maxTrades) || blockTimestamp.ge(endDate)` flips a
  strategy to `COMPLETED`. The handler for `StrategyCompleted` also sets it
  explicitly, so the derivation is a defensive backup if an event is ever
  missed.
- **`Execution` is `@entity(immutable: true)`** — IDs are
  `{strategyId}-{txHashHex}-{logIndex}`. Don't mutate them after
  `handleExecutionCompleted`.
- **`Strategy.nextTriggerAt` / `lastScheduledAt` math mirrors the contract**:
  initial value is `hourAligned + interval` where
  `hourAligned = (ts + 3599) / 3600 * 3600`. If the contract's hour-alignment
  logic ever changes, update `handleStrategyCreated` in lockstep.
- **Price feeds are event-driven, not polled.** Chainlink price *proxies*
  don't emit `AnswerUpdated` — the underlying impl does, and that address
  can rotate when Chainlink upgrades the impl behind the proxy. We track
  **both**: the proxy via `ChainlinkProxy` template listens for
  `AggregatorConfirmed` (impl rotations) and the current impl via the
  `ChainlinkAggregator` template listens for `AnswerUpdated` (round
  stream). Template `context` pins the proxy address at create-time so
  `handleAnswerUpdated` can resolve back to its `PriceFeed` without an
  eth_call per event.
- **Impl resolution happens inside the subgraph.** A `kind: once` block
  handler on every `ChainlinkProxy` dataSource (static bootstrap +
  dynamic template alike) fires on its first active block, calls
  `proxy.aggregator()`, and creates the `ChainlinkAggregator` template
  instance. No off-graph prep step, no impl addresses in the config —
  changing `feed-start-block` is a one-line edit + redeploy.
- **Bootstrap feeds have backfill, dynamic feeds do not.** Static
  bootstrap proxy dataSources have `startBlock = feed-start-block`
  (~14d before the manager deploy), so the once-handler creates the
  aggregator template at that block ⇒ full ~14d of `AnswerUpdated`
  backfill. Feeds first seen via `StrategyCreated`/`StrategyEdited` get
  a `ChainlinkProxy` template registered at the strategy-create block;
  that template's once-handler fires at the same block ⇒ forward-only.
  `PriceFeed.firstSeenAt` lets the FE render a "price data begins
  {date}" empty state when a chart needs older points.
- **Bootstrap impl rotations inside the backfill window** are still
  handled: the proxy dataSource catches `AggregatorConfirmed` and
  registers a fresh aggregator template for the new impl starting from
  the rotation block. The old impl's rounds before the rotation are
  already in the backfill, the new impl's rounds from the rotation
  forward are indexed by the new template — no gap, no missed rounds.

## When the contract changes

Required updates:

1. Regenerate `abis/DCAStrategyManager.json` from the Foundry artifact:
   ```
   jq '.abi' ../core-contracts/out/DCAStrategyManager.sol/DCAStrategyManager.json \
     > abis/DCAStrategyManager.json
   ```
2. Update the event signatures in `subgraph.template.yaml` if the
   `StrategyConfig` tuple shape changes (the parenthesised type list inside
   each `event:` line must match the new struct).
3. Add a new handler entry + mapping function if a new event is added.
4. Update `schema.graphql` if you need to expose a new field on `Strategy`
   or `Execution`.
5. `pnpm run build:base` (this package) must compile clean before deploying.

## Quick commands

```
pnpm --filter @summerfi/summer-earn-dca-subgraph run build:base
pnpm --filter @summerfi/summer-earn-dca-subgraph run deploy:base  # Goldsky CLI
```

## Sign-off

<!-- One line per material change. Most recent on top.
Format: YYYY-MM-DD — author — one-sentence summary. -->

- 2026-05-21 — claude — impl resolution moved **into the subgraph** via a
  `kind: once` block handler (`handleProxyOnce`) on every `ChainlinkProxy`
  dataSource. Dropped the static bootstrap aggregator dataSources, the
  generated `_bootstrapMap.ts`, and the prepare-time `cast call` script;
  `pnpm run prepare:base` is back to a single mustache invocation. Config
  carries proxy addresses only — moving `feed-start-block` is a one-line
  edit.
- 2026-05-21 — claude — config simplified to **proxy-only** for bootstrap
  feeds; `scripts/prepare.mjs` auto-resolves the matching impl at
  `feed-start-block` via `cast call`, so moving the start block doesn't
  require touching impl addresses by hand.
- 2026-05-21 — claude — switched price-feed indexing from polling
  `blockHandlers` to **event-driven**. Two templates (`ChainlinkProxy` for
  `AggregatorConfirmed`, `ChainlinkAggregator` for `AnswerUpdated`),
  template `context` carries the proxy address into the aggregator
  handler. Added `AggregatorRotation` log entity and `PriceFeed.aggregator`
  (current impl). Static bootstrap dataSources resolve impl→proxy via the
  mustache-generated `_bootstrapMap.ts`.
- 2026-05-21 — claude — added `PriceFeed`/`PriceRound` entities, bootstrap
  dataSources for USDC/ETH proxies with a ~14d backfill window, and a
  `ChainlinkAggregator` polling template (`every: 150`) registered from
  `handleStrategyCreated`/`handleStrategyEdited` for user-supplied feeds.
- 2026-05-21 — claude — added `handleStrategyCompleted` for the contract's
  auto-COMPLETED transition; existing `updateStrategyStatus` derivation kept
  as a defensive backup.
- 2026-05-21 — claude — `StrategyConfig` tuple in `StrategyCreated` /
  `StrategyEdited` event signatures dropped from 15 to 14 fields
  (`strategyId` removed); ABI regenerated; mappings unchanged because they
  read `event.params.strategyId`, never `cfg.strategyId`.
- 2026-05-21 — claude — initial CLAUDE.md.
