# summer-earn-institutions-v2-subgraph

Indexes `InstitutionalVaultRegistry` v2 and `RoundsVaultRegistry` events across Base, Mainnet,
Arbitrum, Sonic, and Hyperliquid. Discovery is driven entirely by on-chain registry events —
`InstitutionAdded` spawns `FleetCommander` and `Ark` templates;
`RoundsVaultPairRegistered`/`Updated`/`Deactivated`/`Reactivated` spawn
`RoundsVaultInput`/`RoundsVaultOutput` templates. ERC-1155 round receipts, settled exchange rates,
and per-vault flow aggregates are all captured without manual manifest edits when institutions or
pairs are added.

## What this subgraph answers

- **Receipts per user / round** — ERC-1155 receipt balances grouped by vault, round, and lifecycle
  state.
- **Round history with settled exchange rates** — open/close/settle timestamps and the per-round
  exchange rate snapshot.
- **Per-vault flow aggregates** — cumulative queued deposits, exchange-asset withdrawn, pending
  settlement, plus daily and hourly roll-ups.

The institutional FleetCommander address is stored as `Bytes`; correlate with
`summer-earn-institutions-subgraph` by address on the frontend — there is no cross-subgraph link.

## Build

```bash
pnpm run prepare:base    # render subgraph.yaml from template via mustache
pnpm run build:base      # prepare + codegen + build (wraps the prepare step)
```

Replace `base` with `mainnet`, `arbitrum`, `sonic`, or `hyperliquid`. Append `-staging` for staging
configs (e.g. `build:base-staging`).

## Deploy

Reads `GOLDSKY_DEPLOY_KEY` from `../../.env`. Each deploy script runs the matching build internally:

```bash
pnpm run deploy:base
pnpm run deploy:mainnet
pnpm run deploy:all          # base + mainnet + arbitrum + sonic + hyperliquid
pnpm run deploy:all-staging  # all five chains, staging slugs
```

Goldsky slugs: `summer-institutions-v2-base`, `summer-institutions-v2` (mainnet),
`summer-institutions-v2-arbitrum`, `summer-institutions-v2-sonic`,
`summer-institutions-v2-hyperliquid`; staging slugs append `-staging` (except mainnet which uses
`summer-institutions-v2-staging`).

## Cross-package connections

**Consumes**

- `config/<chain>.json` and `config/<chain>-staging.json` — hand-maintained per-chain files holding
  `registry-address` (InstitutionalVaultRegistry v2) and `rounds-vault-registry-address`. Several
  chains (arbitrum, sonic, hyperliquid) currently use zero-address stubs; they build fine but index
  nothing until real addresses are filled in.
- `src/common/addressProvider.ts` — a local copy of the address-provider helper; kept in sync
  manually with the copies in other subgraph packages.
- `../../.env` — supplies `GOLDSKY_DEPLOY_KEY` at deploy time.

**Consumed by**

- `packages/summer-earn-rwa-app` — endpoint maps for all five chains (prod and staging) are
  hand-listed in `src/config/chains.ts`. Both the prod and staging slug sets must exist for the
  runtime prod/staging switch to work correctly.

**Agent gotchas**

- Two config files per chain (`<chain>.json` + `<chain>-staging.json`) point at different registry
  addresses. Filling one and leaving the other as zero-address is a silent misconfiguration.
- `deploy:all` and `deploy:all-staging` are independent commands — deploying one and omitting the
  other leaves prod/staging out of sync.
- Adding a new chain requires creating both config files, adding all six scripts (`prepare:<chain>`,
  `prepare:<chain>-staging`, `build:<chain>`, `build:<chain>-staging`, `deploy:<chain>`,
  `deploy:<chain>-staging`), and extending the local `src/common/addressProvider.ts`.
- After deploying, the new endpoints must be added manually to
  `summer-earn-rwa-app/src/config/chains.ts`.
