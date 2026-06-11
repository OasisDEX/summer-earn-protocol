---
description: Hardhat Ignition deployment system for governance, staking, core protocol, and fleet contracts, with fleet configuration file conventions.
---

# Deployment

All protocol deployment lives in `packages/deployment`. The system uses **Hardhat Ignition** for deterministic, resumable deployments and a set of interactive TypeScript scripts for fleet-level operations.

> **Node version**: `>=20` is required (the repo `engines` field). The deployment README previously stated Node 16+; that claim is incorrect.

## Directory structure

```
packages/deployment/
├── ignition/
│   └── modules/          # ~25 Ignition modules (core.ts, gov.ts, staking.ts, fleet.ts, gov-v2.ts, bridge.ts, …)
│       ├── arks/
│       ├── rounds/
│       └── utils/
├── scripts/              # 40+ Hardhat run scripts + subdirectories
│   ├── arks/
│   ├── bridge/
│   ├── fleets/
│   ├── governance/
│   └── helpers/
├── config/
│   ├── fleets/           # Fleet config JSONs  (<network>-<ASSET>-<n>.json)
│   ├── cross-chain/      # Cross-chain coordination JSONs (created at deploy time)
│   ├── adapters/
│   └── curation/
├── deployments/          # Output: deployed address records
└── proposals/            # Saved governance proposal JSON files
```

## Deploy commands

All commands accept a `NETWORK` environment variable and delegate to `hardhat run … --network $NETWORK`.

```bash
# Core protocol
NETWORK=base pnpm deploy:core

# Governance (v1)
NETWORK=mainnet pnpm deploy:gov

# Governance v2
NETWORK=mainnet pnpm deploy:gov-v2

# Staking
NETWORK=mainnet pnpm deploy:staking

# Fleet (interactive — see Fleet Deployment below)
NETWORK=base pnpm deploy:fleet

# Individual Ark
NETWORK=base pnpm deploy:ark

# Deployment status (Ignition chain records)
pnpm deploy:status:arbitrum   # chain-42161
pnpm deploy:status:base       # chain-8453

# Contract verification
NETWORK=arbitrum pnpm verify:arbitrum
NETWORK=base pnpm verify:base

# Visualise Ignition dependencies
pnpm visualize:core
```

## Governance deployment (`deploy-gov`)

Deploys the governance system in this order via `ignition/modules/gov.ts`:

1. `ProtocolAccessManager`
2. `SummerTimelockController`
3. `SummerToken`
4. `SummerGovernor` (+ `SummerVestingWalletFactory`)
5. `SummerRewardsRedeemer`

Default parameters (confirmed in `ignition/modules/gov.ts`):

| Parameter | Value |
|---|---|
| Voting delay | 60 seconds |
| Voting period | 600 seconds |
| Proposal threshold | 10,000 SUMMER |
| Quorum fraction | 4% |

## Staking deployment (`deploy-staking`)

Deploys via `ignition/modules/staking.ts`:

1. `StakedSummerToken` (xSUMR — non-transferable governance token)
2. `SummerStaking` — lockup from 0 to 3 years; early-unstake penalties 2–20%
3. `SummerVestingWalletsEscrow` — escrow for vesting wallet staking

## Core protocol deployment (`deploy-core`)

Deploys via `ignition/modules/core.ts`:

1. `DutchAuctionLibrary`
2. `ConfigurationManager`
3. `TipJar`
4. `FleetCommanderRewardsManagerFactory`
5. `HarborCommand`
6. `Raft`
7. `AdmiralsQuarters`

See [FleetCommander](../contracts/core/reference/contracts/fleet-commander.md), [HarborCommand](../contracts/core/reference/contracts/harbor-command.md), [Raft](../contracts/core/reference/contracts/raft.md), and [AdmiralsQuarters](../contracts/core/reference/contracts/admirals-quarters.md) in the contract reference.

## Fleet deployment (`deploy-fleet`)

```bash
NETWORK=base pnpm deploy:fleet
```

The script is interactive: it prompts you to select a fleet configuration file, then:

1. Deploys `FleetCommander`
2. Deploys all configured Arks
3. Sets up permissions and configurations

A deployment record is written to `deployments/fleets/<FleetName>_<network>_deployment.json`.

## Fleet configuration files

Fleet configs live in `config/fleets/` and follow the naming pattern:

```
<network>-<ASSET>-<n>.json
```

Examples from the current directory listing: `base-USDC-1.json`, `arbitrum-USDT-1.json`, `mainnet-WETH-2.json`, `sonic-USDCe-1.json`, `hyperliquid-USDC-1.json`.

> **Correction**: the deployment README example named the file `usdc-base-USDC-1.json` — that file does not exist. The actual pattern is `<network>-<ASSET>-<n>.json`.

Files with a `.bummer.json` suffix are staging/test variants used internally.

### Config schema

```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "symbol": "LVUSDC",
  "assetSymbol": "USDC",
  "initialMinimumBufferBalance": "0",
  "initialRebalanceCooldown": "600",
  "depositCap": "100000000",
  "initialTipRate": "1000000000000000000",
  "network": "base",
  "details": "",
  "arks": [
    {
      "type": "AaveV3Ark",
      "params": {
        "asset": "USDC",
        "protocol": "aaveV3"
      }
    }
  ]
}
```

> **Correction**: the deployment README example showed `initialRebalanceCooldown: 3600` and `depositCap: 1000000000`. The real `base-USDC-1.json` has `600` and `100000000` respectively.

### Supported Ark types

The `ArkType` enum currently has **36 members**. The following are a representative selection — see `packages/deployment/types/config-types.ts` for the complete list:

`AaveV3Ark`, `CompoundV3Ark`, `ERC4626Ark`, `MorphoVaultArk`, `SkyUsdsPsm3Ark`, `SparkArk`, `MorphoArk`, `PendleLPArk`, `PendlePTArk`, `SkyUsdsArk`, `MoonwellArk`, `SyrupArk`, `SkyRewardsArk`, `SiloArk`, `SiloArkV2`, `OriginETHArk`, `ArmArk`, `FluidLiteArk`, `AeraArk`, `StargateV2PoolArk`, `SiUSDArk`, `FluidFTokenArk`, `PsmLiteERC4626Ark`, `Psm3ERC4626Ark`, `HyperlendArk`, `HypurrArk`, `WisdomTreeArk`, `MorphoV2VaultArk`, `MapleInstitutionalArk`, `UpshiftArk`, `OriginUSDArk`, `SuperstateArk`, …

## Governance proposals

Proposals are created and managed through dedicated scripts:

```bash
# Submit a proposal
NETWORK=mainnet pnpm gov:submit-proposal

# Execute after timelock
NETWORK=mainnet pnpm gov:execute-proposal

# Merge multiple proposals into one transaction
pnpm gov:merge-proposals   # always runs on mainnet
```

`gov:merge-proposals` reads proposal JSON files from `proposals/`, requires at least two selections, and writes a merged file as `proposals/merged_proposal_<timestamp>.json`. Proposals for different governors cannot be merged (the script enforces matching `governorId`).

## Merkle reward distribution

```bash
pnpm generate-merkle-root
```

Input: `token-distributions/input/{chainId}/merkle-redeemer/{file}.json` — a map of `address → amount (wei string)`.

Output: `token-distributions/output/{chainId}/merkle-redeemer/{file}.json` — includes `merkleRoot`, `totalAmount`, `addressCount`, and per-address `{ amount, proof }` entries.
