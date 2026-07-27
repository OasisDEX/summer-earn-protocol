# Summer Governance Contracts

`@summerfi/earn-gov-contracts` contains all Solidity governance contracts for the Summer protocol:
the SUMR token, governor, timelocks, staking, rewards, vesting, and decay logic.

## Key Contracts

| Contract                                       | Purpose                                                                           |
| ---------------------------------------------- | --------------------------------------------------------------------------------- |
| `SummerToken.sol`                              | ERC20 governance token (SUMR) extending LayerZero OFT for cross-chain transfers   |
| `SummerGovernor.sol` / `SummerGovernorV2.sol`  | On-chain governance with cross-chain proposal execution and decay-weighted voting |
| `SummerTimelockController.sol`                 | Timelock for governance-controlled upgrades                                       |
| `RwaTimelock.sol`                              | Per-institution timelock deployed for each RWA institution                        |
| `StakedSummerToken.sol`                        | Staked SUMR representation (sSUMR)                                                |
| `SummerStaking.sol`                            | Staking logic and reward distribution                                             |
| `GovernanceRewardsManager.sol`                 | Manages decay-adjusted governance reward flows                                    |
| `DecayController.sol`                          | Configures and computes voting power decay (linear or exponential)                |
| `SummerVestingWallet.sol` / `V2`               | Vesting wallets with cliff and quarterly schedules                                |
| `SummerVestingWalletFactory.sol` / `FactoryV2` | Factory contracts for deploying vesting wallets                                   |
| `SummerVestingWalletsEscrow.sol`               | Escrow for batched vesting wallet deployment                                      |
| `WrappedStakingToken.sol`                      | Wrapped staking token used in governance accounting                               |

## Build and Test

```shell
# Build (runs under default profile: viaIR=true, optimizer=false, solc 0.8.28)
pnpm build

# Run tests (sets FOUNDRY_PROFILE=test automatically)
pnpm test

# Coverage report
pnpm coverage

# Generate Solidity docs (output: docs/generated/)
pnpm docs:gen

# Format Solidity files
pnpm format:fix
```

Do not run `forge build` or `forge test` directly — the `pnpm test` script sets
`FOUNDRY_PROFILE=test`; omitting this will use the default profile which has the same compiler flags
but skips any test-profile-specific remappings.

## Cross-Package Connections

**Consumes (devDependencies):**

- `@summerfi/access-contracts`, `@summerfi/config-contracts`, `@summerfi/rewards-contracts` — base
  interfaces and access control
- `@summerfi/voting-decay` — decay math library used by `DecayController`
- `@summerfi/percentage-solidity` — percentage math primitives
- `@summerfi/math-utils`, `@summerfi/constants` — shared numeric helpers
- `@summerfi/dependencies`, `@summerfi/legacy-dependencies` — Foundry lib remappings; LayerZero
  (`@layerzerolabs/`) resolves through `legacy-dependencies/node_modules/`, not root `node_modules`

**Consumed by:**

- `@summerfi/earn-protocol-contracts` — remaps `@summerfi/earn-gov-contracts/` (and its `test/` dir)
  for cross-package test inheritance
- `@summerfi/deployment` — imports ABIs and interfaces for gov, staking, and `RwaTimelock`
  deployments

**Agent gotchas:**

- `RwaTimelock` is deployed once per RWA institution; the set of institutions is maintained in
  `deployment` scripts and must be updated in sync whenever a new institution is added.
- LayerZero peer configuration (chain endpoints, OFT peers) is hand-maintained across deployment
  scripts — changes to `SummerToken` OFT wiring must be reflected in deployment and any cross-chain
  test fixtures.

## Documentation

GitBook reference: [Governance Contracts](../../gitbook/governance/reference/README.md) — covers all
contracts listed above including `DecayController`, `RwaTimelock`, and all vesting variants.
