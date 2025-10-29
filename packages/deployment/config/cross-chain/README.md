# Cross-Chain Configuration

This directory contains configuration files that define cross-chain relationships between hub and satellite fleets. These files are **generated incrementally** during the deployment process and evolve through three phases.

## Configuration Lifecycle

### Phase 1: Satellite Deployment
**Created by:** `deploy-xchain-fleetproxy.ts`

```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "sourceChainId": 0,  // Not yet known
  "hubFleetName": "",
  "destinations": [
    {
      "chainId": 8453,
      "name": "base",
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x6bDCf1dCAd15e11D7d7B90F5b017aB1fc049dC0f",
          "crossChainArkAddress": "",  // Not yet deployed
          "satelliteFleetAddress": "0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17"
        }
      ]
    }
  ]
}
```

### Phase 2: Hub Deployment
**Updated by:** `deploy-xchain-ark.ts`

```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "sourceChainId": 10,  // Now known
  "hubFleetName": "Bummer_SuperLazyVault_LowerRisk_USDC",
  "destinations": [
    {
      "chainId": 8453,
      "name": "base",
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x6bDCf1dCAd15e11D7d7B90F5b017aB1fc049dC0f",
          "crossChainArkAddress": "0x5f311c931e03217aa0eae99eaF15A7b33543Ec75",  // Now deployed
          "satelliteFleetAddress": "0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17"
        }
      ]
    }
  ]
}
```

### Phase 3: Registration Complete
**Verified by:** `verify-setup.ts`

All fields populated, relationships registered in CrossChainRegistry on both chains.

## Field Descriptions

- `fleetName`: Name of the cross-chain fleet configuration
- `sourceChainId`: Chain ID of the hub chain (set in Phase 2)
- `hubFleetName`: Name of the hub fleet (set in Phase 2)
- `destinations`: Array of destination chain configurations
  - `chainId`: Chain ID of the destination chain
  - `name`: Human-readable name for the destination chain
  - `protocols`: Array of protocol configurations for this destination
    - `protocol`: Protocol name (e.g., "summerfi")
    - `fleetProxyAddress`: Address of the FleetProxy on the destination chain (set in Phase 1)
    - `crossChainArkAddress`: Address of the CrossChainArk on the source chain (set in Phase 2)
    - `satelliteFleetAddress`: Address of the satellite fleet on the destination chain

## Deployment Order (Satellite-First)

### 1. Prerequisites
```bash
# Deploy bridge infrastructure on both chains
npx hardhat run scripts/deploy-xchain-core.ts --network <chain>
npx hardhat run scripts/deploy-xchain-adapters.ts --network <chain>
```

### 2. Satellite Phase (Phase 1)
```bash
# Deploy satellite fleet (if not already deployed)
npx hardhat run scripts/deploy-fleet.ts --network <satellite>

# Deploy FleetProxy on satellite chain
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network <satellite>
```

### 3. Hub Phase (Phase 2)
```bash
# Deploy hub fleet (if not already deployed)
npx hardhat run scripts/deploy-fleet.ts --network <source>

# Deploy CrossChainArk on source chain
npx hardhat run scripts/arks/deploy-xchain-ark.ts --network <source>
```

### 4. Registration Phase (Phase 3)
```bash
# Register relationships and executors on both chains
npx hardhat run scripts/cross-chain/register-relationships.ts --network <source>
npx hardhat run scripts/cross-chain/register-relationships.ts --network <satellite>

# Verify setup
npx hardhat run scripts/cross-chain/verify-setup.ts --network <source>
npx hardhat run scripts/cross-chain/verify-setup.ts --network <satellite>
```

## Adding New Destinations

To add a new satellite chain to an existing cross-chain fleet:

```bash
npx hardhat run scripts/cross-chain/add-destination.ts --network <new-satellite>
```

This will:
1. Prompt for the new destination details
2. Update the cross-chain config
3. Guide you through deploying FleetProxy for the new destination

## Scripts Reference

### Core Deployment Scripts
- `deploy-xchain-fleetproxy.ts` - Deploy FleetProxy, create Phase 1 config
- `deploy-xchain-ark.ts` - Deploy CrossChainArk, update to Phase 2 config

### Cross-Chain Management Scripts
- `cross-chain/register-relationships.ts` - Register ARK↔FleetProxy relationships and executors
- `cross-chain/verify-setup.ts` - Verify configuration and on-chain state
- `cross-chain/add-destination.ts` - Add new satellite to existing cross-chain fleet

### Validation
Each script validates prerequisites and provides clear error messages if dependencies are missing.

## Troubleshooting

### Check Configuration Status
```bash
# The scripts will show current phase and missing fields
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network <chain>
```

### Verify On-Chain State
```bash
# Compare config with on-chain registry state
npx hardhat run scripts/cross-chain/verify-setup.ts --network <chain>
```

### Common Issues
- **"Prerequisites not met"**: Run prerequisite scripts first (bridge, governance, core)
- **"Cross-chain config not found"**: Deploy FleetProxy first to create Phase 1 config
- **"Configuration is incomplete"**: Complete the satellite-first deployment order