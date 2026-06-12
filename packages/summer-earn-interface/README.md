# summer-earn-interface

Next.js 16 web application (React 19, wagmi 3, viem 2, TanStack Query 5) that provides the user
interface for the Summer Earn protocol. It covers fleet browsing, vault deposit/withdraw flows,
vesting and staking, institutional access, rewards harvesting, interest-rate data dashboards, and
role/access-manager views across five chains: Ethereum mainnet, Arbitrum, Base, Sonic, and
Hyperliquid.

## Key source areas

| Path                         | Purpose                                                                                                                                                                                                                                       |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/app/`                   | Next.js App Router pages: `fleet/`, `institutions/`, `vesting/`, `vesting-staking/`, `summer-staking/`, `rewards/`, `roles/`, `access-manager/`, `interest-rates/`, `intent-system/`, etc.                                                    |
| `src/config/environments.ts` | Per-environment (`production`/`staging`), per-chain address maps for HarborCommand, Raft, ProtocolAccessManager, and token/vesting contracts                                                                                                  |
| `src/config/chains.ts`       | `CHAIN_NAMES`, `CHAIN_RPC_URLS` (20+ fallback RPCs per chain), `VIEM_CHAIN_ENTITIES`, and four subgraph URL maps: `CHAIN_SUBGRAPH_URLS`, `CHAIN_INSTITUTIONS_SUBGRAPH_URLS`, `CHAIN_PROTOCOL_SUBGRAPH_URLS`, `CHAIN_GOVERNANCE_SUBGRAPH_URLS` |
| `src/config/deployment/`     | Deployment address snapshots: `index.json` (protocol config) and `deployed/<chain>.json` (Ignition outputs)                                                                                                                                   |
| `src/contracts/`             | Contract interaction helpers (e.g. `Raft.ts`)                                                                                                                                                                                                 |
| `src/hooks/`                 | React hooks for chain interaction, environment detection, staking, vesting, etc.                                                                                                                                                              |
| `scripts/sync-config.js`     | Copies `../../deployment/config/index.json` and `../../deployment/ignition/deployments/chain-*/deployed_addresses.json` into `src/config/deployment/`                                                                                         |

## Build / dev commands

```
pnpm dev          # next dev
pnpm build        # next build
pnpm start        # next start
pnpm lint         # eslint .
pnpm lint:fix     # eslint . --fix
pnpm format       # prettier check
pnpm format:fix   # prettier write
pnpm sync-config  # sync deployment addresses from packages/deployment into src/config/deployment/
```

## Cross-package connections

**Consumes:**

- `packages/deployment` — `sync-config` reads `config/index.json` and
  `ignition/deployments/chain-*/deployed_addresses.json`; run `pnpm sync-config` after any
  deployment to refresh the local snapshots.

**No other packages consume `summer-earn-interface`** — it is a standalone application package.

## Agent gotchas

1. **`src/config/environments.ts` — hand-maintained address maps.** Every contract address
   (HarborCommand, Raft, ProtocolAccessManager, token, vesting factory, escrow) is hardcoded per
   `(production|staging) × chainId`. Many entries carry `// TODO: Add actual address` comments where
   the same address was copy-pasted across chains. Adding a new chain requires updating every
   `Record<Environment, Record<number, Address>>` map in this file for both environments.

2. **`src/config/chains.ts` — four independent subgraph URL maps.** `CHAIN_SUBGRAPH_URLS`,
   `CHAIN_INSTITUTIONS_SUBGRAPH_URLS`, `CHAIN_PROTOCOL_SUBGRAPH_URLS`, and
   `CHAIN_GOVERNANCE_SUBGRAPH_URLS` are all separate `Record<ChainId, string>` objects. Adding a
   chain requires a new entry in all four maps, plus `CHAIN_NAMES`, `CHAIN_RPC_URLS`,
   `CHAIN_BLOCK_EXPLORERS`, and `VIEM_CHAIN_ENTITIES`.

3. **`scripts/sync-config.js` — CHAIN_NAMES is a second copy.** The chain ID → name map inside
   `sync-config.js` is independent of the one in `src/config/chains.ts`; both must be updated when
   adding a chain.

4. **`src/config/deployment/` — snapshot, not live.** The `deployed/<chain>.json` files are written
   by `pnpm sync-config` from the `deployment` package outputs. They go stale after any redeployment
   until the script is re-run.
