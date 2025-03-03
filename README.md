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
- `typescript-config`: Base `tsconfig.json`s configurations

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
