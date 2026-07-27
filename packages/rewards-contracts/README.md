# rewards-contracts

Solidity package (`@summerfi/rewards-contracts`) providing the staking rewards and Merkle-based
reward redemption contracts used across the Summer protocol.

## Key contracts

- **`StakingRewardsManagerBase`** (`src/contracts/StakingRewardsManagerBase.sol`) — abstract base
  for staking reward logic; `FleetCommanderRewardsManager` (core-contracts) and
  `GovernanceRewardsManager` (gov-contracts) both inherit from it.
- **`SummerRewardsRedeemer`** (`src/contracts/SummerRewardsRedeemer.sol`) — Merkle-tree reward
  distributor gated by `ProtocolAccessManaged` (`@summerfi/access-contracts`).
- **`SummerRewardsRedeemerOwnable`** (`src/contracts/SummerRewardsRedeemerOwnable.sol`) — same
  Merkle distribution logic, gated by `Ownable` instead of the protocol access manager.

Interfaces live in `src/interfaces/`: `IStakingRewardsManagerBase`,
`IStakingRewardsManagerBaseErrors`, `ISummerRewardsRedeemer`.

## Build and test

```bash
# Run Foundry tests
pnpm test

# Coverage (IR pipeline)
pnpm coverage

# Generate NatSpec docs
pnpm docs:gen

# Format Solidity sources
pnpm format:fix
```

## Cross-package connections

**Consumes:**

- `@summerfi/access-contracts` — `ProtocolAccessManaged` base used by `StakingRewardsManagerBase`
  and `SummerRewardsRedeemer`.
- `@summerfi/constants` — shared numeric constants.
- `@summerfi/voting-decay` — referenced as a workspace dependency.
- `@summerfi/dependencies` — shared Foundry/remapping setup.

**Consumed by:**

- `@summerfi/core-contracts` — `FleetCommanderRewardsManager` inherits `StakingRewardsManagerBase`;
  `AdmiralsQuarters` imports the `IStakingRewardsManagerBase` and `ISummerRewardsRedeemer`
  interfaces.
- `@summerfi/gov-contracts` — `GovernanceRewardsManager` imports `StakingRewardsManagerBase`.
- `@summerfi/intent-system` and `@summerfi/deployment` — list this package as a dependency.

**Gotchas:**

- Any new reward token or root-management role added here must be reflected in the inheriting
  contracts in `core-contracts` and `gov-contracts`; there is no runtime registry — callers are
  hard-linked.

## Documentation

GitBook reference:
[contracts/rewards/reference/README.md](../../gitbook/contracts/rewards/reference/README.md)
(SUMMARY.md line 347).

## License

BUSL-1.1
