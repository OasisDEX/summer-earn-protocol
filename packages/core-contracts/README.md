# @summerfi/earn-protocol-contracts

Core smart contracts for the Summer.fi Earn Protocol — the on-chain yield optimization system. User
deposits flow into **Fleets** (ERC-4626 vaults orchestrated by a `FleetCommander`), which allocate
capital across **Arks**: isolated adapters that integrate external yield sources. Keepers rebalance
allocations within governance-set caps; protocol fees ("tips") are routed to the treasury and used
for buy-and-burn.

## Architecture

| Component                 | Contracts                                                                                                                                | Responsibility                                                                                                                                                                        |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Fleet orchestration**   | `FleetCommander`, `FleetCommanderConfigProvider`, `FleetCommanderCache`, `FleetCommanderPausable`                                        | ERC-4626 vault that accepts deposits, manages the buffer, and rebalances assets across its Arks within per-Ark deposit caps.                                                          |
| **Arks (yield adapters)** | `Ark` (base), `ArkConfigProvider`, `ArkWithSwap`, `ArkWithWithdrawalRequest`, plus 41 protocol-specific arks under `src/contracts/arks/` | Each Ark wraps one external venue (Aave, Morpho, Pendle, Sky, Superstate, Silo, …) behind a uniform board/disembark/harvest interface. Only the owning FleetCommander can move funds. |
| **Buffer & rebalancing**  | `BufferArk` (in `arks/`), keeper-driven rebalance on `FleetCommander`                                                                    | Holds idle liquidity for instant withdrawals; keepers move funds between the buffer and Arks.                                                                                         |
| **Routing**               | `AdmiralsQuarters`, `AdmiralsQuartersWhitelist`, `ProtectedMulticall`                                                                    | User-facing bundler for deposits/withdrawals across Fleets with integrated swapping.                                                                                                  |
| **Fees & burn**           | `Tipper`, `FlexibleTipper`, `TipJar`, `Raft`, `BuyAndBurn`, `AuctionManagerBase`                                                         | Accrue protocol tips, collect Ark rewards (`Raft`), and convert them via auctions for buy-and-burn.                                                                                   |
| **DCA**                   | `src/contracts/DCA/` (`DCAStrategyManager`)                                                                                              | Stateless, hash-committed dollar-cost-averaging between Fleets.                                                                                                                       |
| **Institutional / RWA**   | `InstitutionalVaultRegistry`, `src/contracts/institutional/`, `src/contracts/rounds-vault/`                                              | Permissioned vaults and round-based subscription/redemption for real-world-asset strategies.                                                                                          |
| **Command**               | `HarborCommand`                                                                                                                          | Registry/entry point coordinating FleetCommanders.                                                                                                                                    |

Access control, configuration, and cross-chain bridging live in sibling packages
(`@summerfi/access-contracts`, `@summerfi/config-contracts`, `@summerfi/chain-bridge-contracts`).
Contracts under `src/contracts/legacy/` and `src/contracts/arks/legacy/` are deprecated and retained
for reference only.

### Ark catalog

41 live arks integrate (among others): Aave V3, Compound V3, Morpho & MetaMorpho, Pendle
(PT/LP/oracle), Sky (USDS/PSM), Superstate, Maple/Syrup, Silo, Moonwell, Fluid, Origin (ETH/USD),
Aera, Benji, WisdomTree, Stargate V2, and generic ERC-4626 vaults. See the GitBook "Ark Catalog"
page or `src/contracts/arks/` for the full list.

## Build & test

```bash
pnpm build          # forge build (outputs ABIs) + abi.sh copies them
pnpm test           # forge test, excludes invariant tests
pnpm test:invariant # invariant tests only
pnpm test:fuzz      # fuzz tests only (match testFuzz_)
pnpm format:fix     # prettier --write on *.sol (run after every edit)
pnpm docs:gen       # forge doc → docs/generated/
```

Fork tests require the relevant `*_RPC_URL` env vars defined in `foundry.toml` `[rpc_endpoints]`:
`MAINNET_RPC_URL`, `BASE_RPC_URL`, `ARBITRUM_RPC_URL`, `SONIC_RPC_URL`, `OPTIMISM_RPC_URL`,
`HYPERLIQUID_RPC_URL`, `SEPOLIA_RPC_URL`.

## Cross-package connections

**Consumes** (declared in `devDependencies`):

| Package                            | What it provides                   |
| ---------------------------------- | ---------------------------------- |
| `@summerfi/access-contracts`       | Access-management base contracts   |
| `@summerfi/config-contracts`       | Config provider base contracts     |
| `@summerfi/chain-bridge-contracts` | Cross-chain bridge interfaces      |
| `@summerfi/earn-gov-contracts`     | Governance contracts               |
| `@summerfi/dutch-auction`          | Auction logic used by `BuyAndBurn` |
| `@summerfi/rewards-contracts`      | Reward distribution contracts      |
| `@summerfi/percentage-solidity`    | Fixed-point percentage math        |
| `@summerfi/price-solidity`         | Price math utilities               |
| `@summerfi/voting-decay`           | Voting-decay logic                 |

**Consumed by**:

- `@summerfi/deployment` — deploys these contracts and reads their ABIs.
- `@summerfi/intent-system` — imports ABIs and types for intent execution.

**Agent gotchas**:

- Adding a new Ark requires **4 files minimum**: the contract in `src/contracts/arks/`, an interface
  in `src/interfaces/arks/`, an error interface in `src/errors/`, and an event interface in
  `src/events/` — per the `ark-development` skill (`packages/skills/ark-development/SKILL.md`).
- This package has its **own `foundry.toml` `[rpc_endpoints]`** list (lines 48–58). It is not shared
  with `packages/deployment/foundry.toml`. When enabling a new chain for fork tests, add the entry
  here explicitly.
- `pnpm build` runs `abi.sh` after `forge build` to copy ABI files. Running bare `forge build` will
  not update downstream ABI imports.

## Documentation

Generated NatSpec reference and architecture guides are published in the project's GitBook space
(see `gitbook/contracts/core/` in the repo root). NatSpec is the source of truth for per-contract
API docs — edit the `.sol` sources, not the generated pages.
