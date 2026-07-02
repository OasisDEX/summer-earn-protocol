# @summerfi/summer-earn-dca-app

Next.js 16 / React 19 / wagmi 3 frontend for creating and managing DCA strategies on Base. Users
select a source and target fleet (discovered on-chain via `HarborCommand`), configure execution
intervals and price guardrails, approve token spend through Permit2, and submit to
`DCAStrategyManager`. A price API route (`/api/prices/[chainId]/[token]`) caches Chainlink-subgraph
data with Next.js 16 `'use cache'` directives and falls back to DeFiLlama when subgraph data is
sparse.

## Key contracts / exports

| File                             | Role                                                                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/abis/DCAStrategyManager.ts` | Hand-regenerated ABI; must be kept in sync with `packages/core-contracts/out/DCAStrategyManager.sol/DCAStrategyManager.json`                |
| `src/abis/HarborCommand.ts`      | ABI for on-chain fleet registry enumeration                                                                                                 |
| `src/abis/FleetCommander.ts`     | ABI for per-fleet `asset()` reads                                                                                                           |
| `src/abis/Permit2.ts`            | Canonical Permit2 ABI                                                                                                                       |
| `src/config/addresses.ts`        | `DCA_STRATEGY_MANAGER_ADDRESSES`, `HARBOR_COMMAND_ADDRESSES`, `KNOWN_TOKEN_ADDRESSES`, `FEED_BY_ASSET_ADDRESS` (all hand-copied, Base only) |
| `src/config/chains.ts`           | RPC fallback list, subgraph URL, block explorer                                                                                             |
| `src/lib/strategy/commitment.ts` | `keccak256` commitment mirror of the on-chain struct                                                                                        |
| `src/lib/prices/`                | Chainlink-subgraph primary + DeFiLlama fallback + composite cascade                                                                         |

## Build / test commands

```sh
# Development server
pnpm --filter @summerfi/summer-earn-dca-app dev

# Production build
pnpm --filter @summerfi/summer-earn-dca-app build

# Type-check
pnpm --filter @summerfi/summer-earn-dca-app exec tsc --noEmit

# Lint
pnpm --filter @summerfi/summer-earn-dca-app lint

# Format (run after every edit, before commit)
pnpm --filter @summerfi/summer-earn-dca-app format:fix
```

No test script is defined in `package.json`.

## Cross-package connections

**Consumes**

- `packages/deployment/config/index.json` — canonical source for `DCAStrategyManager` and
  `HarborCommand` addresses. There is no sync script; addresses in `src/config/addresses.ts` are
  copied by hand. Comments in that file cite the source paths.
- `packages/core-contracts/out/DCAStrategyManager.sol/DCAStrategyManager.json` — ABI source.
  Regenerate `src/abis/DCAStrategyManager.ts` by hand after any contract change (see CLAUDE.md for
  the one-liner).
- `packages/summer-earn-dca-subgraph` — provides the `summer-dca-base` subgraph consumed by
  `src/lib/subgraph/` and the price API route.

**Consumed by:** nothing (leaf app).

**Agent gotchas**

- All addresses in `src/config/addresses.ts` are hand-maintained. When a new deployment is made,
  update `DCA_STRATEGY_MANAGER_ADDRESSES`, `HARBOR_COMMAND_ADDRESSES`, `KNOWN_TOKEN_ADDRESSES`, and
  `FEED_BY_ASSET_ADDRESS` together.
- The app is Base-only. Adding a chain requires new entries in every `Record<ChainId, ...>` map in
  both `chains.ts` and `addresses.ts`.
- The `arb` entry in `KNOWN_TOKEN_ADDRESSES` is flagged in a comment as a placeholder
  bridged-variant address pending finalisation by the protocol team.
- `StrategyConfigTuple` field order must exactly match `IDCAStrategyManager.StrategyConfig`; drift
  causes `CommitmentMismatch` reverts on every write that re-passes the config.

## GitBook docs

DCA concepts and contract reference live under `gitbook/` in the repo root:

- `gitbook/concepts/dca.md`
- `gitbook/contracts/core/reference/contracts/DCA/dca-strategy-manager.md`
