# Institution Inspector

A read-only, graph-style tool to inspect deployed **Institutions → Fleets → Arks** with their
system contracts, roles and timelocks. Built for the Summer Earn protocol team to visually explore
deployments — not a management tool.

Data is reconstructed from the local **`packages/deployment`** config + Ignition deployments, and
(optionally) verified against the **on-chain registries / PAM**.

## Quick start

```bash
# from packages/institution-inspector
pnpm generate -- --network base --env production            # config + Ignition only
pnpm generate -- --network base --env production --onchain  # + on-chain verification
pnpm dev                                                    # view at http://localhost:3000
```

The generator writes `data/graph.<network>.<env>.json`; the viewer loads every file in `data/`.

## How it works

Two passes, merged by deterministic node id:

- **Pass A (config + Ignition, no RPC):** the topology backbone. Reads
  `config/institutions/<name>/index(.test).json` (`fleets` map, `deployedContracts`, governance,
  timelocks) and enriches contract metadata (e.g. `AaveV3Ark`) from the Ignition
  `deployed_addresses.json` + `artifacts/`. Always works offline.
- **Pass B (`--onchain`, viem multicall):** verifies the config against chain — `PAM.hasRole` for
  each declared role edge, `InstitutionalVaultRegistry` membership + wiring, RoundsVaultRegistry
  input/output. Sets `verifiedOnChain` / `drift` flags. Degrades gracefully to the config-only
  graph if RPC fails (`onchain.fetched = false`).

### Viewer

- **Drill-down:** Institutions → an institution (system contracts, timelocks, fleets) → a fleet
  (FleetCommander, BufferArk, Arks, RoundsVaults). Breadcrumb navigates back up.
- **Edges:** teal/solid = verified on-chain, red/dashed = drift (config ≠ chain), grey/dashed =
  unverified/config-only. Toggle **verified only** to hide unconfirmed claims.
- **Refresh on-chain:** re-runs Pass A + Pass B live via `/api/refresh` (local-only; reads the
  sibling `deployment` package from disk).
- Click any leaf node for a detail drawer (address copy + block-explorer link).

## Layout

```
scripts/                generator (run with tsx)
  generate-graph.ts       entrypoint: --network --env [--onchain]
  build-config-graph.ts   Pass A
  ignition-metadata.ts    address -> contractName from Ignition
lib/
  graph-schema.ts         zod schema + types (shared by generator and viewer)
  subgraph.ts             drill-down filter + dagre layout
  load-graph.ts           read data/*.json
  onchain/                Pass B (abis, role hashing, augment)
components/               React Flow viewer (GraphExplorer + node cards)
app/                      Next.js app (page + /api/refresh)
data/                     generated graph snapshots
```

## Notes / TODO

- Theme adopted from `summer-earn-interface`.
- Multi-network: add RPCs to `config/chains.ts`, then `pnpm generate -- --network <net> --env <env> --onchain`.
- Possible follow-ups: enumerate on-chain role holders not present in config (needs
  `AccessControlEnumerable` or event scan), per-ark on-chain config checks.
