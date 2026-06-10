# @summerfi/earn-protocol-contracts

Core smart contracts for the Summer.fi Earn Protocol — the on-chain yield
optimization system. User deposits flow into **Fleets** (ERC-4626 vaults
orchestrated by a `FleetCommander`), which allocate capital across **Arks**:
isolated adapters that integrate external yield sources. Keepers rebalance
allocations within governance-set caps; protocol fees ("tips") are routed to
the treasury and used for buy-and-burn.

## Architecture

| Component | Contracts | Responsibility |
|---|---|---|
| **Fleet orchestration** | `FleetCommander`, `FleetCommanderConfigProvider`, `FleetCommanderCache`, `FleetCommanderPausable` | ERC-4626 vault that accepts deposits, manages the buffer, and rebalances assets across its Arks within per-Ark deposit caps. |
| **Arks (yield adapters)** | `Ark` (base), `ArkConfigProvider`, `ArkWithSwap`, `ArkWithWithdrawalRequest`, plus 40+ protocol-specific arks under `src/contracts/arks/` | Each Ark wraps one external venue (Aave, Morpho, Pendle, Sky, Superstate, Silo, …) behind a uniform board/disembark/harvest interface. Only the owning FleetCommander can move funds. |
| **Buffer & rebalancing** | `BufferArk` (in `arks/`), keeper-driven rebalance on `FleetCommander` | Holds idle liquidity for instant withdrawals; keepers move funds between the buffer and Arks. |
| **Routing** | `AdmiralsQuarters`, `AdmiralsQuartersWhitelist`, `ProtectedMulticall` | User-facing bundler for deposits/withdrawals across Fleets with integrated swapping. |
| **Fees & burn** | `Tipper`, `FlexibleTipper`, `TipJar`, `Raft`, `BuyAndBurn`, `AuctionManagerBase` | Accrue protocol tips, collect Ark rewards (`Raft`), and convert them via auctions for buy-and-burn. |
| **DCA** | `src/contracts/DCA/` (`DCAStrategyManager`) | Stateless, hash-committed dollar-cost-averaging between Fleets. |
| **Institutional / RWA** | `InstitutionalVaultRegistry`, `src/contracts/institutional/`, `src/contracts/rounds-vault/` | Permissioned vaults and round-based subscription/redemption for real-world-asset strategies. |
| **Command** | `HarborCommand` | Registry/entry point coordinating FleetCommanders. |

Access control, configuration, and cross-chain bridging live in sibling
packages (`@summerfi/access-contracts`, `@summerfi/config-contracts`,
`@summerfi/chain-bridge`). Contracts under `src/contracts/legacy/` and
`src/contracts/arks/legacy/` are deprecated and retained for reference only.

### Ark catalog

40+ live arks integrate (among others): Aave V3, Compound V3, Morpho &
MetaMorpho, Pendle (PT/LP/oracle), Sky (USDS/PSM), Superstate, Maple/Syrup,
Silo, Moonwell, Fluid, Origin (ETH/USD), Aera, Benji, WisdomTree, Stargate V2,
and generic ERC-4626 vaults. See the GitBook "Ark Catalog" page or
`src/contracts/arks/` for the full list.

## Build & test

```bash
forge build           # solc 0.8.28, via_ir
forge test            # unit tests
forge test --match-path 'test/fork/**'   # fork tests (require RPC env vars)
forge fmt             # format
```

This is a Foundry package within the pnpm/Turbo monorepo; `pnpm build` /
`pnpm test` from the repo root run it through the shared pipeline.

## Documentation

Generated NatSpec reference and architecture guides are published in the
project's GitBook space (see `gitbook/contracts/core/` in the repo root).
NatSpec is the source of truth for per-contract API docs — edit the `.sol`
sources, not the generated pages.
