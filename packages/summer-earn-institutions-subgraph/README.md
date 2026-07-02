# summer-earn-institutions-subgraph

Indexes the `InstitutionalVaultRegistry` (v1) across mainnet, arbitrum-one, base, sonic, and
hyperliquid. It listens for `InstitutionAdded`, `InstitutionRemoved`, and
`InstitutionAdmiralsQuartersUpdated` events to track `Institution` entities, then spawns
`AdmiralsQuarters`, `HarborCommand`, `ProtocolAccessManager`, `FleetCommander`, and `Ark`
data-source templates so that institutional vault activity (deposits, withdrawals, rebalances,
snapshots) is captured automatically. A polling interval handler handles periodic metric updates.

## Key source files

- `src/mappings/institutionalVaultRegistry.ts` — entry-point handlers for registry events; spawns
  `AdmiralsQuartersTemplate`, `HarborCommandTemplate`, and `ProtocolAccessManagerTemplate` on
  `InstitutionAdded`.
- `src/mappings/fleetCommander.ts`, `ark.ts` — template mappings for institutional vaults and arks.
- `src/common/addressProvider.ts` — hand-maintained copy with 186 hardcoded addresses (see gotchas).
- `config/<chain>.json` — per-chain registry address, start block, interval, and optional grafting
  config.
- `schema.graphql` — defines `Institution`, `Vault`, `Ark`, `YieldAggregator`, snapshots, and
  access-control entities.

## Build and deploy commands

All commands require `graph-cli` and a `GOLDSKY_API_KEY` sourced from `../../.env`.

```bash
# Prepare + codegen + build for a single chain
pnpm build:base
pnpm build:arbitrum
pnpm build:mainnet
pnpm build:sonic
pnpm build:hyperliquid

# Deploy to Goldsky (runs the matching build first)
pnpm deploy:base       # slug: summer-institutions-base/<version>
pnpm deploy:arbitrum   # slug: summer-institutions-arbitrum/<version>
pnpm deploy:mainnet    # slug: summer-institutions/<version>
pnpm deploy:sonic      # slug: summer-institutions-sonic/<version>
pnpm deploy:hyperliquid # slug: summer-institutions-hyperliquid/<version>

pnpm deploy:all        # runs all five deploys in sequence

pnpm format:fix        # prettier over *.ts / *.tsx
```

## Cross-package connections

**Consumes:**

- `config/<chain>.json` — hand-maintained file holding the `InstitutionalVaultRegistry` address and
  start block for each chain. Must be created manually when enabling a new chain.
- `src/common/addressProvider.ts` — a hand-duplicated copy of the address provider from the protocol
  subgraph. Changes to either copy must be mirrored manually in the other.
- `abis/` — hand-copied ABI files; must be updated if the on-chain contracts change.

**Consumed by:**

- `packages/summer-earn-interface` — queries the deployed slugs (`summer-institutions`,
  `summer-institutions-base`, etc.) via URLs hardcoded in `src/config/chains.ts`. There is no npm
  dependency; the coupling is through the Goldsky slug names and the GraphQL schema shape.

**Agent gotchas:**

- New chain: manually create `config/<chain>.json` with the registry address and start block, add
  the matching `prepare:<chain>`, `build:<chain>`, and `deploy:<chain>` scripts to `package.json`,
  and extend the `addressProvider.ts` network branch.
- New institution: no edits needed — `InstitutionAdded` events trigger auto-discovery at runtime.
- `src/common/addressProvider.ts` is a duplicated copy that is not auto-synced; it must be kept in
  sync with the protocol subgraph's copy by hand.
- `scripts/` and `utils/` directories at the package root are empty.

## Gitbook

No institutions subgraph section exists in `gitbook/SUMMARY.md` yet. The closest entry is
[Subgraphs Overview](../../gitbook/data/README.md).
