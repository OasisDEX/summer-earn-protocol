# Institution Inspector

A read-only, graph-style tool to inspect deployed **Institutions → Fleets → Arks** with their system
contracts, roles and timelocks. Built for the Summer Earn protocol team to visually explore
deployments — not a management tool.

Data is reconstructed from the local **`packages/deployment`** config + Ignition deployments, and
(optionally) verified against the **on-chain registries / PAM**.

## Quick start

```bash
# from packages/institution-inspector

# regenerate ALL graphs (base + mainnet, prod + staging, on-chain) then start the viewer:
pnpm dev:fresh                                              # http://localhost:3000

# or step by step:
pnpm generate:all                                          # regenerate every network/env (--onchain)
pnpm dev

# single graph:
pnpm generate -- --network base --env production            # config + Ignition only
pnpm generate -- --network mainnet --env production --onchain  # + on-chain verification
```

The generator writes `data/graph.<network>.<env>.json`; the viewer loads every file in `data/` and
lists them in the network/env dropdown. Currently wired: **base** and **mainnet** (production +
staging).

## How it works

Two passes, merged by deterministic node id:

- **Pass A (config + Ignition, no RPC):** the topology backbone. Reads
  `config/institutions/<name>/index(.test).json` (`fleets` map, `deployedContracts`, governance,
  timelocks) and enriches contract metadata (e.g. `AaveV3Ark`) from the Ignition
  `deployed_addresses.json` + `artifacts/`. Always works offline.
- **Pass B (`--onchain`, viem multicall):** verifies the config against chain — `PAM.hasRole` for
  each declared role edge, `InstitutionalVaultRegistry` membership + wiring, RoundsVaultRegistry
  input/output. Sets `verifiedOnChain` / `drift` flags. Degrades gracefully to the config-only graph
  if RPC fails (`onchain.fetched = false`).

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

## Cross-package connections

**Consumes:** `packages/deployment` — read directly off the filesystem, **not** as an npm/workspace
dependency (this package declares no `@summerfi/deployment` dep). `scripts/generate-graph.ts`
resolves the deployment root as `path.resolve(__dirname, '..', '..', 'deployment')` (overridable via
`DEPLOYMENT_DIR`); `scripts/build-config-graph.ts` reads institution/fleet JSON under
`<deploymentRoot>/config/`, and `scripts/ignition-metadata.ts` reads
`<deploymentRoot>/ignition/deployments/chain-<id>/deployed_addresses.json` to resolve addresses to
contract names. On-chain verification (`--onchain` / Pass B in `lib/onchain/`) queries RPCs directly
via `viem`, independent of any other package.

**Consumed by:** nobody — this is a standalone, human-facing viewer with no other package importing
it.

**Gotchas:**

- Because the deployment coupling is a raw relative filesystem path rather than a package
  dependency, restructuring `packages/deployment`'s `config/` or `ignition/deployments/` layout will
  silently break the generator scripts here with no type error or install-time warning — grep this
  package's `scripts/` before renaming those paths.
- Graph data under `data/` is a generated snapshot (`pnpm generate:all`), not sourced live by the
  viewer at request time — stale snapshots look like a real deployment-state bug if regeneration is
  forgotten after a deploy.

## Deployment

Hosted on **AWS Amplify** as a static export (Terraform: `module "institution_inspector"` in
`infrastructure/main.tf`, platform `WEB`). The Amplify buildspec runs `pnpm build:static`
(`scripts/build-static.mjs`), which stashes `app/api`, builds with `NEXT_PUBLIC_STATIC_EXPORT=1` and
serves the `out/` directory — there is no server runtime and no `/api/refresh` in the hosted build.

- **Production:** pushes to `main` touching this package auto-build the Amplify `main` branch;
  `.github/workflows/amplify-prod-deploys.yaml` records the result in the repo's GitHub Deployments
  UI.
- **PR previews:** add the `preview` label to a same-repo PR that touches this package;
  `.github/workflows/amplify-previews.yaml` builds a preview branch and posts the URL as a sticky PR
  comment. Removing the label or closing the PR tears the preview down.
- **Data freshness:** the deployed viewer renders the committed `data/*.json` snapshots — run
  `pnpm generate:all` and commit the result after protocol deployments, or the hosted graph goes
  stale (see Gotchas above).

## Notes / TODO

- Theme adopted from `summer-earn-interface`.
- Multi-network: add the network to `TARGETS` in `scripts/generate-all.ts` and RPCs to
  `config/chains.ts`; empty network/env combos are skipped automatically.
- Possible follow-ups: enumerate on-chain role holders not present in config (needs
  `AccessControlEnumerable` or event scan), per-ark on-chain config checks.
