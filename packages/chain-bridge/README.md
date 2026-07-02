# Chain Bridge

This package (`@summerfi/chain-bridge-contracts`) implements the cross-chain asset and message
bridging layer for a not-yet-deployed cross-chain Fleet architecture. `BridgeRouter` coordinates
transfers and state reads across chains through pluggable bridge adapters (LayerZero, Stargate),
gated by governance/executor access control; `CrossChainRegistry` tracks the Ark ↔ FleetProxy
relationships and adapter/peer configuration that routing depends on.

**Status:** not deployed. Excluded from the root `AGENTS.md`/`CLAUDE.md` Package Map's "Contracts"
bullet and from the published GitBook docs for the same reason (see `docs/DOCS_PLAYBOOK.md`). Unlike
`intent-system`, this package is under active development with a full passing test suite — treat it
as pre-launch, not abandoned.

For the architecture and operator runbook, start with `docs/cross-chain/OVERVIEW.md`:

- Overview: `docs/cross-chain/OVERVIEW.md`
- Rebalancing flow: `docs/cross-chain/REBALANCING_FLOW.md`
- Bridge router and adapters: `docs/cross-chain/BRIDGE_ROUTER_AND_ADAPTERS.md`
- Registry and security: `docs/cross-chain/REGISTRY_AND_SECURITY.md`
- Operations playbook: `docs/cross-chain/OPERATIONS_PLAYBOOK.md`

## Key contracts

| Contract                      | Role                                                                                         |
| ----------------------------- | -------------------------------------------------------------------------------------------- |
| `BridgeRouter`                | Central router; coordinates transfers/reads across adapters, executor/governance-gated.      |
| `CrossChainRegistry`          | Registers Ark ↔ FleetProxy relationships and adapter/peer configuration used by routing.    |
| `CrossChainConfigManaged`     | Shared config-access base for router/registry (pause state, executor/governance addresses).  |
| `BaseBridgeAdapter`           | Common adapter scaffolding extended by each bridge-specific adapter.                         |
| `CrossChainReceiverBase`      | Common inbound-message handling extended by receiving contracts.                             |
| `LayerZeroAdapter`            | `IMessageAdapter`/`IAssetAdapter` implementation over LayerZero (OApp + OFT-style transfer). |
| `StargateAdapter`             | `IAssetAdapter` implementation over Stargate V2 pools.                                       |
| `LayerZeroOptionsHelper`      | Builds LayerZero execution-options bytes.                                                    |
| `BridgeCodec` / `BridgeTypes` | Message encoding and shared structs/enums.                                                   |
| `OftCmdHelper`                | Builds Stargate/LayerZero OFT compose-message payloads.                                      |

Interfaces (`src/interfaces/`) split by concern: `IBridgeRouter`, `IBridgeAdapter`,
`IAssetAdapter`/`IMessageAdapter` (adapter capability split), `ICrossChainReceiver`,
`ICrossChainRegistry`, `ICrossChainConfigManaged`, `ICrossChainArk`,
`IFleetCommanderMinimal`/`IHarborCommandMinimal`/`IFleetProxyInflightTracking`/
`IInflightAssetTracking` (minimal mirrors of core-contracts types — see Gotchas), and the vendored
`IStargateReceiver`/`IStargateRouter`/`IStargateV2`.

## Build and test

```bash
forge build   # from packages/chain-bridge — see Gotchas: no package.json script runs this for you
forge test
forge coverage --ir-minimum
```

## Cross-package connections

**Consumes:**

- `@summerfi/access-contracts` — `ProtocolAccessManaged` (executor/governance role gating on
  `BridgeRouter`).
- `@summerfi/dependencies` — OpenZeppelin, forge-std, solmate via `remappings.txt`.
- `@layerzerolabs/*`, `@stargatefinance/stg-evm-v2`, `solidity-bytes-utils` — real third-party
  bridge SDKs (not vendored through `external-dependencies`).

**Consumed by:**

- `packages/core-contracts` — declares the workspace dependency and has the
  `@summerfi/chain-bridge/=node_modules/@summerfi/chain-bridge-contracts/src/` remapping, but the
  only **live** reference is `src/interfaces/IFleetProxy.sol` importing `ICrossChainReceiver`. The
  actual cross-chain Ark/FleetProxy implementations
  (`src/contracts/arks/legacy/CrossChainArk.sol.old`, `src/contracts/legacy/FleetProxy.sol.old`) are
  retired (`.sol.old`, excluded from compilation) — this package currently has no live consumer of
  its router/adapter contracts, only of one receiver interface.
- `packages/deployment` — declares the workspace dependency and has the remapping wired for when
  deployment scripts are written, but nothing under `scripts/`/`ignition/` references it yet.

**Gotchas:**

- **`package.json` defines no `build` or `test` script** (only `format`, `format:fix`, `docs:gen`).
  Turbo resolves both `pnpm build` and `pnpm test` at the repo root to a no-op for this package
  (verified via `turbo run test --filter=@summerfi/chain-bridge-contracts --dry-run=json` →
  `"command": "<NONEXISTENT>"`) — the ~140 tests under `test/unit/` and `test/integration/` (all
  passing as of this writing) are **not** exercised by CI or `pnpm test`. Run `forge test` directly
  inside this package until `test`/`build`/`coverage` scripts are added to `package.json` matching
  the pattern in sibling contract packages (e.g. `packages/access-contracts/package.json`).
- The `IFleetCommanderMinimal`/`IHarborCommandMinimal`/`IFleetProxyInflightTracking` interfaces are
  intentionally **decoupled mirrors** of the real core-contracts types, not imports of them — this
  package does not depend on `core-contracts` at all (only the reverse, one-way `IFleetProxy` edge
  above). Keep them in sync by hand if the real interfaces they mirror change shape.
- `foundry.toml` already has the full `[doc]` + `extra_output` GitBook-docs scaffolding (matching
  every other documented contracts package), but this package is deliberately **not** listed in
  `scripts/docs/docs.config.json` — see `docs/DOCS_PLAYBOOK.md` and the Status note above. Don't add
  it there without a deliberate decision to publish pre-launch cross-chain docs.
