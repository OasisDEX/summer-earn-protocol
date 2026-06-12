# Summer Earn Oracle Dashboard

A Next.js 16 (App Router) monitoring interface for the Summer Earn RWA Oracle system. It polls
`RwaOracle` and `OracleRegistry` contracts across five chains (mainnet, Base, Arbitrum, Sonic,
Hyperliquid) via viem multicall, fetches off-chain NAV from the WisdomTree public API, and displays
staleness/deviation health status per ticker. A separate `/test-yield` route shows `TestYieldToken`
state sourced from `yield-deployments.json`. Deployed via Vercel.

## Key exports / types

- `fetchOracleStats(network)` — main data-fetching function in `lib/oracle-data.ts`; returns
  `TickerStats[]`
- `TickerStats` — per-oracle data shape: `ticker`, `onChainPrice`, `nonce`, `signers`,
  `oracleStatus` (`healthy | warning | stale`), `history`
- `NetworkType` — `'base' | 'arbitrum' | 'mainnet' | 'sonic' | 'hyperliquid'`
- `RWA_ORACLE_ABI` / `ORACLE_REGISTRY_ABI` — hand-maintained in `lib/constants.ts` (not imported
  from a shared package)

## Commands

```bash
pnpm dev          # next dev
pnpm build        # next build
pnpm start        # next start
pnpm lint         # eslint
pnpm format       # prettier --check
pnpm format:fix   # prettier --write
```

There are no test scripts in `package.json`.

## Cross-package connections

**Consumes:**

- `oracle-cli/src/deployments.json` — hand-copied into `lib/deployments.json`. No sync script exists
  in either package. Every oracle deployment requires a manual copy; the file is Zod-parsed at
  module load (`lib/oracle-data.ts` line 64), so a malformed copy crashes the app at boot.
- `oracle-cli/src/yield-deployments.json` — hand-copied into `lib/yield-deployments.json` for the
  `/test-yield` route. Same manual-copy requirement.
- `config/chains.ts` — hand-maintained RPC fallback lists for all five chains; adding a sixth chain
  requires a new entry here plus copying the updated deployment files.

**Consumed by:** none (leaf application).

**Agent gotchas:**

- After any oracle deployment, copy both `deployments.json` and `yield-deployments.json` from
  `oracle-cli/src/` into `lib/` manually — there is no automation.
- Adding a new chain requires: (1) a new `CHAIN_RPC_URLS` entry in `config/chains.ts`, (2) updated
  copies of both deployment JSON files, and (3) a new `NetworkType` case in `lib/oracle-data.ts`.

## GitBook reference

RWA Oracle contracts (interfaces and implementations) are documented under
[contracts/oracles/reference](../../gitbook/contracts/oracles/reference/README.md). There is no
dedicated oracle-dashboard page in `gitbook/SUMMARY.md`.
