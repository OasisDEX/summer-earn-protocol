# summer-earn-protocol-subgraph

Indexes the Summer Earn protocol across mainnet, arbitrum-one, base, sonic, and hyperevm
(HyperLiquid). Static data sources cover `HarborCommand` (for `FleetCommanderEnlisted` events),
`GovernanceRewardsManager`, and `SummerStakingV2` (production + staging). Dynamic templates —
`FleetCommanderTemplate`, `ArkTemplate`, and `FleetCommanderRewardsManagerTemplate` — are spawned
from those events and handle deposits, withdrawals, transfers, rebalances, ark additions/removals,
caps, tips, staking rewards, and periodic vault/ark snapshots. Deployed to Goldsky under the slugs
`summer-protocol` (mainnet) and `summer-protocol-<chain>` for other networks; the `version` field in
`package.json` is used verbatim as the Goldsky deployment tag.

## Key source files

| File                                       | Role                                                                                                                                                                                   |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `subgraph.template.yaml`                   | Mustache template; rendered to `subgraph.yaml` per chain via `config/<chain>.json`                                                                                                     |
| `config/<chain>.json`                      | Hand-maintained: network slug, `HarborCommand` address + start block, `GovernanceRewardsManager`, `SummerStakingV2` (prod + staging), interval-handler block interval, grafting config |
| `src/common/addressProvider.ts`            | Hand-maintained ~40 token/oracle/ENS addresses per network; new chains require a new branch here                                                                                       |
| `src/mappings/harborCommand.ts`            | Handles `FleetCommanderEnlisted`; spawns `FleetCommanderTemplate`                                                                                                                      |
| `src/mappings/ark.ts` / `src/utils/ark.ts` | Handles ark events; `getArkProductId` parses on-chain `details()` JSON (keys: `protocol`, `pool`, `vault`, `siUSDVault`, `chainId`); hard-excludes `BufferArk` by name                 |
| `schema.graphql`                           | Public GraphQL schema                                                                                                                                                                  |

## Build and deploy commands

```bash
# Render subgraph.yaml for a chain, codegen, and compile
pnpm build:mainnet
pnpm build:base
pnpm build:arbitrum
pnpm build:sonic
pnpm build:hyperliquid

# Deploy to Goldsky (sources ../../.env for GOLDSKY_TOKEN)
pnpm deploy:mainnet
pnpm deploy:base
pnpm deploy:arbitrum
pnpm deploy:sonic
pnpm deploy:hyperliquid
pnpm deploy:all        # runs all five in sequence
```

There are no lint or test scripts in this package's `package.json`.

## Cross-package connections

**Consumes:**

- `config/<chain>.json` — hand-maintained per-chain contract addresses and start blocks; must be
  created manually when enabling a new chain.
- `src/common/addressProvider.ts` — hand-maintained token/oracle/ENS address map; this file is
  duplicated (not shared) with the institutions and auctions subgraph packages, so new-chain
  additions must be repeated in each.
- `abis/` — hand-copied ABIs including oracle and ENS contracts.
- `../../.env` — sourced at deploy time for the Goldsky API token.

**Consumed by:**

- `packages/summer-earn-interface` — references Goldsky slugs `summer-protocol[-<chain>]` via
  `subgraph.staging.oasisapp.dev` proxy in `src/config/chains.ts`. Slugs are hand-listed there and
  must match the deploy slugs in this package.

**Agent gotchas:**

- `config/mainnet-staging.json` exists but no `prepare:mainnet-staging` script exists in
  `package.json`; it is effectively orphaned.
- Fleets and Arks are auto-discovered from on-chain events — no config edit is needed per fleet/ark
  — but only if the fleet is enlisted in the `HarborCommand` address pinned in
  `config/<chain>.json`.
- `getArkProductId` hard-excludes arks named `BufferArk` and has fixed fallback keys for the
  `details()` JSON. New Ark types with different `details()` shapes will return a null product id
  until `src/utils/ark.ts` is updated.
- The `version` string in `package.json` is the Goldsky deployment tag; bumping it creates a new
  Goldsky subgraph version rather than overwriting the previous one.
- `addressProvider.ts` is duplicated across the protocol, institutions, and auctions subgraph
  packages — edits for a new chain must be applied in each copy separately.

## GitBook

[Protocol Subgraph](../../gitbook/data/protocol-subgraph.md) — `gitbook/data/protocol-subgraph.md`
(linked from `gitbook/SUMMARY.md` under "Subgraphs Overview").
