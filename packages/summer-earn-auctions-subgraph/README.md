# summer-earn-auctions-subgraph

Indexes Dutch-auction activity for Summer Earn protocol Rafts across mainnet, Base, Arbitrum One,
and Sonic. Two static data sources act as discovery roots: `ConfigManager` (emits `RaftUpdated` to
spawn Raft data-source templates, and is also used as a template itself) and
`InstitutionalVaultRegistry` (emits `InstitutionAdded`). Each Raft template then handles
`ArkRewardTokenAuctionStarted`, `AuctionFinalized`, `TokensPurchased`, and
`ArkAuctionParametersSet`. Deployed to Goldsky under the slugs `summer-auctions` (mainnet),
`summer-auctions-base`, `summer-auctions-arbitrum`, and `summer-auctions-sonic`.

## Key contracts / source files

| Name                                         | Role                                                        |
| -------------------------------------------- | ----------------------------------------------------------- |
| `ConfigManager`                              | Discovery root — `RaftUpdated` spawns Raft templates        |
| `InstitutionalVaultRegistry`                 | Discovery root — `InstitutionAdded` for institutional Rafts |
| `Raft` (template)                            | Handles all auction lifecycle events                        |
| `src/mappings/configManager.ts`              | Handler for `RaftUpdated`                                   |
| `src/mappings/institutionalVaultRegistry.ts` | Handler for `InstitutionAdded`                              |
| `src/mappings/raft.ts`                       | Auction event handlers                                      |

## Build and deploy commands

```sh
# Render manifest, codegen, and build for a specific chain
pnpm build:mainnet
pnpm build:base
pnpm build:arbitrum
pnpm build:sonic

# Deploy (requires GOLDSKY_API_KEY in ../../.env)
pnpm deploy:mainnet
pnpm deploy:base
pnpm deploy:arbitrum
pnpm deploy:sonic

# Deploy all chains at once
pnpm deploy:all
```

Each `build:<chain>` script runs
`mustache config/<chain>.json subgraph.template.yaml > subgraph.yaml`, then
`graph codegen && graph build`.

## Cross-package connections

**Consumed by:** `packages/summer-earn-auctions-frontend` — `src/lib/config.ts` references the
`subgraphEndpoint` URL per chain (currently pointing at the staging proxy
`subgraph.staging.oasisapp.dev`, not directly at Goldsky).

**Config files (`config/<chain>.json`):** Hand-maintained. The shape uses **nested objects with
dotted mustache paths** (`config-manager.address`, `institutional-vault-registry.address`). This
differs from every other subgraph package in this repo, which use flat configs. Copying a flat
config from a sibling will produce a broken manifest.

**ABIs (`abis/`):** Hand-copied, including multiple oracle ABIs. If a contract ABI changes upstream,
this directory must be updated manually.

## Agent gotchas

- `institutional-vault-registry` is set to `0x0000000000000000000000000000000000000000` in both
  `config/mainnet.json` and `config/base.json`. Institutional auction Rafts on those chains will not
  be indexed until the real address is filled in and the subgraph is redeployed.
- There are no `prepare:hyperliquid`, `build:hyperliquid`, or `deploy:hyperliquid` scripts and no
  `config/hyperliquid.json`. Hyperliquid is not supported here.
- When adding a new chain: create `config/<chain>.json` with the nested-object shape (not flat), add
  `prepare`/`build`/`deploy` scripts in `package.json`, and use `0x0` for
  `institutional-vault-registry` if no registry is deployed there yet.
