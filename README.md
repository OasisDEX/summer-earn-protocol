
[![](https://canada1.discourse-cdn.com/flex009/uploads/summer/original/1X/41245886b684401dfcfbc8db7642973e9f3f74e1.png)](https://summer.fi)

# Summerfi Earn Protocol

## TLDR;

### Initialize the repository

```bash
$ pnpm i
```

### Install Foundry

```bash
$ curl -L https://foundry.paradigm.xyz | bash
$ foundryup
```

Restart your terminal after running the above commands.

## Structure

### Packages

- `contracts-protocol`: Core contracts for the Summer Earn Protocol
- `gov-contracts`: Governance contracts for the Summer Earn Protocol
- `voting-decay`: Voting Decay library
- `access-control`: Access control contracts for the Summer Earn Protocol
- `rewards-contracts`: Rewards contracts for the Summer Earn Protocol
- `dutch-auction`: Dutch Auction contracts for the Summer Earn Protocol
- `external-dependencies`: External dependencies for the Summer Earn Protocol
- `eslint-config`: Base `eslint` configurations
- `jest-config`: Base `jest` configurations
- `tenderly-utils`: Utility functions for interacting with Tenderly API
- `typescript-config`: Base `tsconfig.json` configurations

## Commands

### Build

To build all apps and packages, run the following command:

```shell
pnpm build
```

### Develop

To develop all apps and packages, run the following command:

```shell
pnpm dev
```

## Useful Links

Learn more about the power of Turborepo:

- [Tasks](https://turbo.build/repo/docs/core-concepts/monorepos/running-tasks)
- [Caching](https://turbo.build/repo/docs/core-concepts/caching)
- [Remote Caching](https://turbo.build/repo/docs/core-concepts/remote-caching)
- [Filtering](https://turbo.build/repo/docs/core-concepts/monorepos/filtering)
- [Configuration Options](https://turbo.build/repo/docs/reference/configuration)
- [CLI Usage](https://turbo.build/repo/docs/reference/command-line-reference)

[![codecov](https://codecov.io/gh/OasisDEX/summer-earn-protocol/branch/main/graph/badge.svg?token=ZDPGVH2NVG)](https://codecov.io/gh/OasisDEX/summer-earn-protocol)

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

Scope includes `SummerStaking.sol`, `SummerVestingWalletsEscrow.sol`, `SummerGovernorV2.sol`, `StakedSummerToken.sol`.

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
- Coverage excludes common non-source files via `--no-match-coverage '(script|test|TestBase|Mock|Test)'`.
- Every test must include failure paths (e.g., `vm.expectRevert(...)`), otherwise it is not considered valid.

### Foundry tips

```bash
# Filter tests by contract or pattern
forge test -m YourTestName -vvv

# Gas snapshots
forge snapshot
```
