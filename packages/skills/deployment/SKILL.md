---
name: protocol-deployments
description: Professional guide for adding new Arks and protocols to the Summer Earn Protocol deployment system using Hardhat Ignition and interactive scripts.
---

# Protocol Deployments

Guide for adding new Arks and protocols to the Summer Earn Protocol deployment infrastructure.

## When to Use This Skill

- Integrating a new Ark implementation into the deployment flow
- Adding a new external protocol/vault for existing Ark types
- Updating deployment configurations across mainnet and testnets

## Core Workflow

### 1. Configuration Types

Update [config-types.ts](../../deployment/types/config-types.ts):
- Add the new Ark to the `ArkType` enum.
- Add it to the `arkTypes` array for CLI selection.
- If adding a new protocol, add its config shape to `BaseConfig['protocolSpecific']`.

### 2. Ignition Module

Create `packages/deployment/ignition/modules/arks/[ark-name].ts`:
- Use `buildModule` from `@nomicfoundation/hardhat-ignition/modules`.
- Define parameters (`vault`, `arkParams`, plus protocol-specific) and deploy with `m.contract()`.
- Export the module factory function and a contracts type.

### 3. Deployment Script

Create `packages/deployment/scripts/arks/deploy-[ark-name].ts`:
- Implement `getUserInput()` for interactive prompts using `prompts` library.
- Export a main `deploy[ArkName]Ark(config, arkParams?)` function that supports both interactive and programmatic modes.
- Validate all addresses using helpers from [validation.ts](../../deployment/scripts/helpers/validation.ts).
- Construct the `arkDetails` object and validate with `validateArkDetails()`.
- Call `hre.ignition.deploy()` with the ignition module.

### 4. Integration

Update [ark-deployment.ts](../../deployment/scripts/common/ark-deployment.ts):
- Import the new deployment function.
- Add a case to both `deployArk()` (programmatic) and `deployArkInteractive()` (CLI) switch blocks.

### 5. Config Data

Update [index.json](../../deployment/config/index.json) and [index.test.json](../../deployment/config/index.test.json):
- Add protocol and vault addresses under the relevant network section.

## `arkDetails` Object

The `arkDetails` object is serialized into the contract's `details` field and is critical for the UI. It is validated by a Zod schema (`ArkDetailsSchema` in [zod-schemas.ts](../../deployment/scripts/helpers/zod-schemas.ts)).

**Required fields** (schema-enforced):
- `protocol`: string (e.g., `AaveV3`, `Morpho`, `Morpho_V2`, `Sky`, `InfiniFi`, `StargateV2`)
- `pool`: Address — core interaction address (Pool for Aave, MarketID for Morpho, Vault for ERC4626, StakingRewards for Sky)
- `chainId`: number

**Common optional fields**: `type`, `asset`, `marketAsset`, `vaultName`, `gateway`, `vaultId`, `marketId`, `marketName`, `siloId`, `fToken`, `syrupAddress`, `armAddress`, `poolAddress`, `vault`, `stakingRewardsAddress`, `originETHAddress`, `sparkPool`, `mToken`, `psm3Address`, `psmLiteAddress`, `stargatePool`, `compoundV3Pool`, `aaveV3Pool`.

Always call `validateArkDetails(arkDetails, 'context')` before deploying.

## Naming Conventions

**Ark Name** (used as contract name and deployment identifier):
- Format: `[Protocol]-[VaultIdentifier]-[TokenSymbol]-[ChainId]`
- Examples: `AaveV3-USDC-1`, `ERC4626-Euler_Base_USDC-USDC-8453`, `SkyRewards-DAI-USDC-1`

**Module Name** (Ignition deployment ID):
- Format: `${envLabel}${fleetName}_${arkName.replace(/-/g, '_')}`
- `envLabel` is `'staging_'` for bummer (staging) fleets, empty string for production.

## `BaseArkParams`

All deployment scripts receive a `BaseArkParams` object:
```typescript
{
  token: { address: Address, symbol: Token }
  depositCap: string
  maxRebalanceOutflow: string
  maxRebalanceInflow: string
  maxDepositPercentageOfTVL: string
  fleetName: string
  isBummer?: boolean
  version: number
}
```
Protocol-specific scripts extend this with additional fields (e.g., `vaultId`, `marketId`, `stargatePoolAddress`).

## Validation Helpers

| Function | Use For |
|----------|---------|
| `validateAddress(addr, label)` | Single address validation |
| `validateConfigAddressEntry(obj, key, label)` | Nested config object lookups |
| `validateErc4626Address(addr, label)` | ERC4626 vault addresses |
| `validateMarketId(id, label)` | Morpho market IDs (hex string) |
| `validateString(val, label)` | Non-empty string fields |
| `validateToken(config, token)` | Token exists in config |
| `validateArkDetails(details, label)` | Full arkDetails Zod validation |
| `validateVaultName(name, label)` | Vault name format (non-empty protocol prefix) |

## Protocol-Specific Notes

| Protocol | Key Config Path | Notes |
|----------|----------------|-------|
| Aave V3 / Spark / Hyperlend / Hypurr | `protocolSpecific.[protocol].pool` + `.rewards` | Lending pool + rewards controller |
| Compound V3 | `protocolSpecific.compoundV3.pools[token].cToken` + `.rewards` | Comet + CometRewards |
| ERC4626 | `protocolSpecific.erc4626[token][vaultName]` | Generic vault wrapper; `vaultName` must follow `Protocol_Identifier` format |
| Morpho (market) | `protocolSpecific.morpho.markets[token][marketName]` | Market ID is a hex string |
| Morpho (vault) | `protocolSpecific.morpho.vaults[token][vaultName]` | V1 vaults |
| Morpho V2 (vault) | `protocolSpecific.morpho.vaultsV2[token][vaultName]` | V2 vaults |
| Sky | `protocolSpecific.sky.psmLite[token]` / `.psm3[token]` / `.staking[key]` | PSM swap + staking |
| Syrup (Maple) | `protocolSpecific.syrup.pools[token].syrup` + `.router` | Pool + Router |
| Maple Institutional | `protocolSpecific.mapleInstitutional.pools[token].pool` | Direct deposit via ERC4626 |
| Silo | `protocolSpecific.silo.pools[token][vaultName]` / `.vaults[token][vaultName]` | Pools vs managed vaults |
| Fluid | `protocolSpecific.fluid.lite[token]` / `.fToken[token]` | Lite (async) vs fToken (ERC4626) |
| Origin | `protocolSpecific.originUSD.originUSD` / `originETH.originETH` + `.arm` | ARM for mainnet only |
| Aera | `protocolSpecific.aera.vaults[token][vaultName].provisioner` | Dynamic vault discovery |
| Stargate V2 | `protocolSpecific.stargate.pools[token]` | Liquidity pool address |
| InfiniFi | `protocolSpecific.infinifi.gateway` + `.siUSD` | Gateway + siUSD vault |
| Pendle | `protocolSpecific.pendle.markets[token].marketAddresses[name]` | LP, PT, and PT Oracle variants |
| Upshift | `protocolSpecific.upshift[token][vaultName]` | Tokenized account vaults |
