# summer-earn-rounds-vaults-subgraph

Indexes `RoundsVaultInput` and `RoundsVaultOutput` pairs that wrap institutional
FleetCommanders. Discovery is driven entirely by `RoundsVaultRegistry` events —
deploy a pair, register it, and the subgraph spawns per-vault data sources
automatically.

## What this subgraph answers

- **Receipts per user / round** — ERC-1155 receipt balances grouped by vault, round, and lifecycle state.
- **Round history with settled exchange rates** — open/close/settle timestamps and the per-round exchange rate snapshot.
- **Per-vault flow aggregates** — cumulative queued deposits, exchange-asset withdrawn, pending settlement, plus daily and hourly roll-ups.

The institutional FleetCommander address is stored as `Bytes`; correlate with the
`summer-earn-institutions-subgraph` by address on the frontend.

## Build

```bash
pnpm run prepare:base    # render subgraph.yaml from template
pnpm run build:base      # codegen + build
```

Networks: `base`, `mainnet`, `arbitrum`, `sonic`, `hyperliquid`. Initial
deployments target chains where rounds vaults exist (Base + Mainnet); the others
land as deployments roll out.

## Deploy

Reads `GOLDSKY_DEPLOY_KEY` from `../../.env`:

```bash
pnpm run deploy:base
pnpm run deploy:mainnet
```
