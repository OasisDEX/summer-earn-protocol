---
name: protocol-deployments
description: Professional guide for adding new Arks and protocols to the Summer Earn Protocol deployment system using Hardhat Ignition and interactive scripts.
---

# Protocol Deployments

Comprehensive guide for adding new Arks and protocols to the Summer Earn Protocol deployment infrastructure.

## When to Use This Skill

- Integrating a new Ark implementation into the deployment flow
- Adding a new external protocol/vault for existing Ark types
- Updating deployment configurations across mainnet and testnets
- Creating new Hardhat Ignition modules for contract deployments

## Core Workflow

### 1. Configuration Types

Update [config-types.ts](../../deployment/types/config-types.ts):
- Add the new Ark to the `ArkType` enum.
- Update the `arkTypes` constant for CLI selection.
- If adding a new protocol, update the `BaseConfig['protocolSpecific']` interface.

### 2. Ignition Module

Create a new module in `packages/deployment/ignition/modules/arks/[ark-name].ts`:
- Use `buildModule` from `@nomicfoundation/hardhat-ignition/modules`.
- Define parameters (`vault`, `arkParams`) and deploy the contract using `m.contract()`.
- **Note**: Some Arks (like Syrup) may require a `version` parameter in the module factory to handle logic changes or salt variations.

### 3. Deployment Script

Create a new script in `packages/deployment/scripts/arks/deploy-[ark-name].ts`:
- Implement interactive input collection using `prompts`.
- Use [validation.ts](../../deployment/scripts/helpers/validation.ts) to validate all addresses and string formats.
- Construct the `arkDetails` object (see Implementation Patterns).
- Call `hre.ignition.deploy` with the module from step 2.

### 4. Integration

Update [ark-deployment.ts](../../deployment/scripts/common/ark-deployment.ts):
- Import the new deployment function.
- Add cases to `deployArk` and `deployArkInteractive` switch blocks.

### 5. Config Data

Update [index.json](../../deployment/config/index.json) and [index.test.json](../../deployment/config/index.test.json):
- Add the protocol and vault addresses under the relevant network section.

## Implementation Patterns & Best Practices

### Crucial: `arkDetails` Object
The `arkDetails` object is serialized into the contract's `details` field and is critical for the UI and analytics. It MUST include:
- `protocol`: Exact protocol identifier (e.g., `AaveV3`, `Morpho`, `Morpho_V2`, `Sky`, `InfiniFi`, `StargateV2`).
- `type`: Integration category (e.g., `Lending`, `Staking`, `Rewards`, `Vault`, `Liquidity Pool`, `ERC4626`).
- `asset`: Underlying token address (e.g., USDC, WETH).
- `marketAsset`: Address of the position/reward token (often same as `asset`, but e.g., `USDS` for Sky Rewards).
- `pool`: Core interaction address (Vault for ERC4626, Pool for Aave, MarketID for Morpho, StakingRewards for Sky).
- `chainId`: Network chain ID (numeric).
- `vaultName`: (Optional) Human-readable name (Silo, Morpho, Aera).
- `rewardsProgram`: (Optional) Program name for rewards-based Arks.
- `armStrategy`: (Optional) Strategy name for Origin ARM Arks.

Always call `validateArkDetails(arkDetails, '...')` before deploying.

### Naming Conventions
- **Ark Name**: `[Protocol]-[VaultIdentifier]-[TokenSymbol]-[ChainId]`
  - Example: `ERC4626-Euler_Base_USDC-USDC-8453`
  - Example: `SkyRewards-DAI-USDC-1`
- **Module Name**: `${envLabel}${fleetName}_${arkName.replace(/-/g, '_')}`
  - **Governance Suffix**: Add `_gov` suffix for modules involving protocol governance or access manager setup.

### Address Validation
- Use `validateAddress(address, 'label')` for all single address lookups.
- Use `validateConfigAddressEntry(configObject, key, 'label')` for lookups in nested config objects (e.g., Sky staking).
- Implement dynamic lookups if the `pool` address is not static (e.g., Aera's `MULTI_DEPOSITOR_VAULT()`).

### Protocol-Specific Patterns
- **Aave V3 / Spark**: `pool` is the Aave/Spark Pool contract.
- **Morpho**: `pool` is the `marketId` (hex). Often requires `urdFactory` and `blue` addresses.
- **Sky**: `marketAsset` is often `USDS`. `pool` is either `psmLite` or `stakingRewards`.
- **Origin**: May require separate logic for Mainnet vs L2s (e.g., handling ARM addresses on Mainnet).
- **Stargate V2**: Type is `Liquidity Pool`. `pool` is the Stargate Pool address.

### Versioning & Salts
Use the `version` field in `BaseArkParams` to drive salt derivation in Ignition modules. This allows deploying multiple instances of the same Ark logic or upgrading logic while maintaining a consistent address pattern where required.
