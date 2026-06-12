# @summerfi/summer-earn-rwa-app

Next.js application for the Summer.fi Earn Protocol **real-world-asset (RWA)** experience —
subscribing to, redeeming from, and monitoring permissioned RWA vaults (e.g. institutional /
round-based strategies). Connects to the protocol contracts via Wagmi + Reown AppKit and reads data
through TanStack Query.

## Stack

- Next.js 16 (App Router) + React 19
- `@wagmi/core` / `@reown/appkit-adapter-wagmi` for wallet + chain interaction
- `@tanstack/react-query` for data fetching/caching
- viem for low-level chain reads

## Develop

```bash
pnpm dev          # start the dev server (http://localhost:3000)
pnpm build        # production build
pnpm start        # serve the production build
pnpm lint         # eslint
pnpm lint:fix     # eslint --fix
pnpm format:fix   # prettier --write
```

Run from the repo root with Turbo (`pnpm --filter @summerfi/summer-earn-rwa-app dev`) or from this
package directory.

> **Note:** this app pins Next.js 16 which has breaking changes from older releases — see
> `AGENTS.md` and consult `node_modules/next/dist/docs/` before changing framework-level code.

## Key source layout

| Path                           | Purpose                                                                                                                                                                                                                                                                                         |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/types/chain.ts`           | `ChainId` string-literal union + `SUPPORTED_CHAIN_IDS` array (currently `'8453' \| '1' \| '42161' \| '146' \| '999'`)                                                                                                                                                                           |
| `src/config/chains.ts`         | Four exported `Record<ChainId, …>` maps: `CHAIN_NAMES`, `CHAIN_RPC_URLS`, `CHAIN_BLOCK_EXPLORERS`, `VIEM_CHAIN_ENTITIES`; plus a private `DEFAULT_INSTITUTIONS_V2_URLS` (`Record<AppEnvironment, Record<ChainId, string>>`) accessed via the exported `getInstitutionsV2SubgraphUrl()` function |
| `src/config/env.ts`            | All `NEXT_PUBLIC_*` reads; `INSTITUTIONS_V2_ENV_BY_CHAIN` maps chain ids to per-chain subgraph URL override env vars                                                                                                                                                                            |
| `src/config/institutions.ts`   | **Hand-maintained** `STAGING_INSTITUTIONS` / `PRODUCTION_INSTITUTIONS` arrays; mirrors `packages/deployment/config/institutions/<name>/index.json` (or `index.test.json` where no `index.json` exists) — no sync script exists                                                                  |
| `src/config/appEnvironment.ts` | `AppEnvironment` type (`'production' \| 'staging'`); default is `'staging'`; stored in an `app-env` cookie                                                                                                                                                                                      |

## Cross-package connections

**Consumes from other packages:**

- `packages/deployment/config/institutions/*/index.json` and `index.test.json` — institution
  contract addresses are copied by hand into `src/config/institutions.ts`. Some institutions only
  have `index.test.json` (no `index.json`). There is no automated sync; every new institution or
  re-deployment requires a manual update to that file.
- `packages/rwa-oracles` — deployed `RwaOracle` contracts whose addresses appear in institution
  fleet configs.

**Consumed by:**

- Nothing in the monorepo imports from this package at runtime. It is a standalone Next.js app.

**Agent gotchas (hand-maintained lists that must stay in sync):**

1. **New chain:** add the chain id to _both_ the `ChainId` union _and_ `SUPPORTED_CHAIN_IDS` in
   `src/types/chain.ts`, then add entries to all four exported records (`CHAIN_NAMES`,
   `CHAIN_RPC_URLS`, `CHAIN_BLOCK_EXPLORERS`, `VIEM_CHAIN_ENTITIES`) and to both sub-maps of
   `DEFAULT_INSTITUTIONS_V2_URLS` (production + staging) in `src/config/chains.ts`, then add the
   `NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_<CHAIN>` key in `src/config/env.ts`.
2. **New institution:** add a full `Institution` entry to `STAGING_INSTITUTIONS` or
   `PRODUCTION_INSTITUTIONS` in `src/config/institutions.ts` — including every fleet's
   `fleetCommander`, `bufferArk`, `arks[]`, `roundsVaultInput`, and `roundsVaultOutput`.
3. **Production subgraph URLs** in `DEFAULT_INSTITUTIONS_V2_URLS.production` currently point at
   `subgraph.staging.oasisapp.dev`; they are intended to be overridden per-chain via
   `NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL_*` env vars in production deployments.

## Related

- RWA oracle contracts: `packages/rwa-oracles`
- Contract split across: `packages/core-contracts`, `packages/config-contracts`,
  `packages/access-contracts`, `packages/gov-contracts`
- Protocol documentation: the project GitBook space
  (`gitbook/governance/reference/contracts/rwa-timelock.md`, `gitbook/contracts/oracles/`)
