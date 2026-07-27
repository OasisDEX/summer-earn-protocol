# Summer Earn Governance Validator

A Next.js 16 application for decoding, validating, and executing governance proposals for the Summer
Earn Protocol. It reads proposal calldata from the governance subgraph, decodes on-chain actions,
and lets a connected wallet execute pending cross-chain proposals by calling `executeBatch` on the
per-chain `SummerTimelockController`.

## Key routes

- **`/`** — main governance proposal validator (calldata decoding / simulation)
- **`/proposals`** — browse on-chain proposals
- **`/cross-chain`** — cross-chain governance proposals with execution support
- **`/create-proposal`**, **`/delegates`**, **`/treasury`** — additional governance views

## Key source files

| File                           | Purpose                                                                                                                               |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `src/config/constants.ts`      | `CHAIN_CONFIG` — hand-maintained timelock + SUMR token addresses per chain ID                                                         |
| `src/config/chains.ts`         | `CHAINS` array (id, name, key, LayerZero eID, tenderlyId) and `CHAIN_THEMES`                                                          |
| `src/config/rpc.ts`            | `CHAIN_RPC_URLS` — hand-curated public RPC fallback lists                                                                             |
| `src/config/index.json`        | Deployment config synced from `packages/deployment`                                                                                   |
| `src/config/deployed/*.json`   | Per-chain deployed addresses synced from `packages/deployment`                                                                        |
| `src/services/subgraph.ts`     | GraphQL client; defaults to `subgraph.staging.oasisapp.dev/summer-protocol-gov-*`, overridable via `NEXT_PUBLIC_<CHAIN>_SUBGRAPH_URL` |
| `src/components/Providers.tsx` | Wallet connection via `@reown/appkit` (not RainbowKit); reads `NEXT_PUBLIC_WALLETCONNECT_ID`                                          |

## Supported chains

| Chain       | ID    | LayerZero eID | tenderlyId |
| ----------- | ----- | ------------- | ---------- |
| Ethereum    | 1     | 30101         | 1          |
| Base        | 8453  | 30184         | 8453       |
| Arbitrum    | 42161 | 30110         | 42161      |
| Sonic       | 146   | 30332         | 146        |
| HyperLiquid | 999   | 30367         | `null`     |

## Commands

```bash
# Install (from repo root)
pnpm install

# Development server (loads ../../.env via dotenv)
pnpm dev

# Production build
pnpm build

# Sync deployment addresses from packages/deployment into src/config/
pnpm sync-config

# Tests
pnpm test

# Format
pnpm format:fix
```

`pnpm dev` reads environment variables from the root `../../.env` file (via `dotenv`). The only
required variable for wallet connectivity is `NEXT_PUBLIC_WALLETCONNECT_ID`; it defaults to `'demo'`
if unset.

## Cross-package connections

**Consumes:**

- `packages/deployment` — `sync-config.js` copies `deployment/config/index.json` and
  `deployment/ignition/deployments/chain-*/deployed_addresses.json` into `src/config/`. Chains not
  present in `scripts/sync-config.js:CHAIN_NAMES` are silently skipped.
- `packages/summer-earn-protocol-gov-subgraph` — provides the governance subgraph that
  `src/services/subgraph.ts` queries for proposal data and cross-chain execution arguments.
- `@summerfi/jest-config` (workspace devDependency) — shared Jest configuration.

**Not consumed by other packages** — this is a standalone Next.js app (`private: true`).

**Agent gotchas (hand-maintained lists that must be updated together when adding a chain):**

1. `scripts/sync-config.js` `CHAIN_NAMES` map — chains missing here are silently skipped during
   `pnpm sync-config`.
2. `src/config/constants.ts` `CHAIN_CONFIG` — timelock and SUMR token addresses.
3. `src/config/chains.ts` `CHAINS` array and `CHAIN_THEMES` record — LayerZero eIDs are hand-copied
   here (not derived from deployment).
4. `src/config/rpc.ts` `CHAIN_RPC_URLS` / `VIEM_CHAIN_ENTITIES` — public RPC fallback lists.
5. `src/config/tokenLists.ts`, `src/config/treasuryWallets.ts`, `src/services/subgraph.ts` —
   per-chain token lists, treasury wallets, and subgraph URL defaults.
6. HyperLiquid has `tenderlyId: null`; any code path that builds a Tenderly simulation URL must
   handle this explicitly.

## GitBook reference

Documented under [Operations: Keepers & Bots](../../gitbook/internal/operations.md) in the internal
section of the GitBook (`gitbook/internal/operations.md`).
