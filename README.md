[![](https://canada1.discourse-cdn.com/flex009/uploads/summer/original/1X/41245886b684401dfcfbc8db7642973e9f3f74e1.png)](https://summer.fi)

# Summerfi Earn Protocol

pnpm + Turborepo monorepo containing the Summer.fi Earn Protocol: Solidity contracts (Foundry),
deployment tooling (Hardhat Ignition), Goldsky subgraphs, and TypeScript/Next.js apps and services.

- Full documentation lives in [`gitbook/`](gitbook/) (built with `pnpm docs:build`).
- Cross-package change checklists (new ark, new chain, new institution, governance redeploys, oracle
  deploys) live in [`AGENTS.md`](AGENTS.md).

## Setup

```bash
# Node deps (postinstall also runs `git submodule update --init`)
pnpm i

# Foundry (forge/cast/anvil)
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Restart your terminal after installing Foundry. RPC URLs (`MAINNET_RPC_URL`, `BASE_RPC_URL`, …) go
in a repo-root `.env`; the list of recognized vars is in `turbo.json` `globalEnv`.

## Commands

```bash
pnpm build      # build all packages (turbo; excludes the Next.js apps — build those with pnpm -F <pkg> build)
pnpm dev        # run dev tasks across packages
pnpm test       # run all tests
pnpm lint       # lint
pnpm format:fix # format
pnpm cicheck    # CI check suite + total coverage
pnpm docs:build # regenerate gitbook/ reference docs (forge doc + TypeDoc + assemble)
```

## Package directory

Contracts (Foundry):

| Package                 | Purpose                                                                                               |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `core-contracts`        | Core Earn Protocol contracts: FleetCommander, ~40 Ark adapters, HarborCommand, AdmiralsQuarters, Raft |
| `gov-contracts`         | Governance: SUMR token, SummerGovernor v1/v2, timelocks, staking, vesting, rewards                    |
| `access-contracts`      | ProtocolAccessManager (V1) and V2 (per-context whitelist + OPERATOR_ROLE for institutional fleets)    |
| `config-contracts`      | ConfigurationManager protocol-wide address registry                                                   |
| `rewards-contracts`     | Staking rewards and Merkle-based reward redemption                                                    |
| `dutch-auction`         | Dutch auction library (linear and exponential decay) used by Raft                                     |
| `rwa-oracles`           | Chainlink-compatible RwaOracle / OracleRegistry contracts for RWA price feeds                         |
| `voting-decay`          | Voting-power decay library for governance                                                             |
| `percentage`            | Fixed-point `Percentage` / `BPS` Solidity math types                                                  |
| `price-utils`           | Base/quote price math library                                                                         |
| `math-utils`            | Fixed-point exponentiation library                                                                    |
| `constants`             | Shared Solidity constants                                                                             |
| `external-dependencies` | Vendored third-party Solidity libraries (single workspace package)                                    |
| `legacy-dependencies`   | Pinned `@layerzerolabs/*` / `solidity-bytes-utils` versions matching deployed gov contracts           |
| `intent-system`         | Intent-based bond system contracts (**not deployed**)                                                 |
| `chain-bridge`          | Cross-chain bridge contracts (**not deployed**)                                                       |

Deployment and ops:

| Package            | Purpose                                                                                                                     |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------- |
| `deployment`       | Hardhat Ignition deploy scripts and per-chain config; `config/index.json` is the source of truth for all on-chain addresses |
| `oracle-cli`       | CLI for deploying/operating RWA oracles; records addresses in `src/deployments.json` / `src/yield-deployments.json`         |
| `oracle-dashboard` | Next.js monitoring UI for the RWA oracle system (hand-copied deployments from oracle-cli)                                   |
| `ark-rebalancer`   | Proof-of-concept Python bot that rebalances a fleet toward the highest-rate ark                                             |
| `tenderly-utils`   | Tenderly REST API / CLI wrappers for fork-based testing                                                                     |

Subgraphs (Goldsky; each has per-chain `config/<network>.json` + `deploy:<network>` scripts):

| Package                                | Purpose                                                                                  |
| -------------------------------------- | ---------------------------------------------------------------------------------------- |
| `summer-earn-protocol-subgraph`        | Core protocol indexing: HarborCommand, fleets, arks, staking (dynamic templates)         |
| `summer-earn-rates-subgraph`           | APR/APY and TVL for underlying DeFi protocols (hand-configured Products per chain)       |
| `summer-earn-protocol-gov-subgraph`    | Governor v1/v2 proposals, votes, roles, timelocks                                        |
| `summer-earn-institutions-subgraph`    | InstitutionalVaultRegistry v1 and institutional vault activity                           |
| `summer-earn-institutions-v2-subgraph` | Registry v2 + RoundsVaultRegistry (separate prod and `-staging` configs/slugs per chain) |
| `summer-earn-auctions-subgraph`        | Raft dutch auction indexing                                                              |
| `summer-earn-dca-subgraph`             | DCAStrategyManager + Chainlink feed indexing (base, mainnet)                             |

Apps and services:

| Package                         | Purpose                                                                                    |
| ------------------------------- | ------------------------------------------------------------------------------------------ |
| `summer-earn-interface`         | Main Next.js app: fleet browsing, deposits/withdrawals, vesting, staking, rewards          |
| `summer-earn-rwa-app`           | Next.js app for the institutional/RWA whitelist stack (hand-maintained institution config) |
| `summer-earn-dca-app`           | Next.js frontend for DCA strategies (Base)                                                 |
| `summer-earn-auctions-frontend` | Next.js app showing and buying Raft dutch auctions                                         |
| `summer-earn-gov-validator`     | Next.js app for decoding, validating, and executing governance proposals                   |
| `summer-earn-gov-alert-bot`     | Node.js service polling governance events and alerting                                     |

Shared tooling:

| Package                                               | Purpose                                          |
| ----------------------------------------------------- | ------------------------------------------------ |
| `eslint-config` / `jest-config` / `typescript-config` | Base lint/test/tsconfig presets                  |
| `skills`                                              | Agent skill guides (ark development, deployment) |

You may also see empty placeholder directories locally (e.g. `configuration-manager-contracts`,
`referral-validator`, `scripts`, `subgraph`, `summer-earn-shareseconds-subgraph`) — they are not
part of the repository.

[![codecov](https://codecov.io/gh/OasisDEX/summer-earn-protocol/branch/h/maple-institutional/graph/badge.svg?token=ZDPGVH2NVG)](https://codecov.io/gh/OasisDEX/summer-earn-protocol)

## Testing and Coverage (Auditor Guide) - Sherlock Contest 29.09.2025

### Clean environment setup

1. Install dependencies

```bash
# Node + pnpm
pnpm i

# Foundry (forge/cast/anvil)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Optional (for HTML coverage report)
sudo apt-get update && sudo apt-get install -y lcov
```

2. Verify toolchain

```bash
forge --version | cat
pnpm --version | cat
```

### Package under audit: @summerfi/earn-gov-contracts

Scope includes `SummerStaking.sol`, `SummerVestingWalletsEscrow.sol`, `SummerGovernorV2.sol`,
`StakedSummerToken.sol`.

Run build, tests, and coverage:

```bash
# Build
pnpm -F @summerfi/earn-gov-contracts build

# Tests (must be 100% passing)
pnpm -F @summerfi/earn-gov-contracts test

# Coverage (target >80%)
pnpm -F @summerfi/earn-gov-contracts coverage

# HTML coverage report (requires lcov)
pnpm -F @summerfi/earn-gov-contracts coverage:report
# Then open: packages/gov-contracts/coverage/index.html
```

Notes:

- Coverage excludes common non-source files via
  `--no-match-coverage '(script|test|TestBase|Mock|Test)'`.
- Every test must include failure paths (e.g., `vm.expectRevert(...)`), otherwise it is not
  considered valid.

### Foundry tips

```bash
# Filter tests by contract or pattern
forge test -m YourTestName -vvv

# Gas snapshots
forge snapshot
```
