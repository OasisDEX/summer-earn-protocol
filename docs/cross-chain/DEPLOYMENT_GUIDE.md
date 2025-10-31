# Cross-Chain Fleet Deployment Guide

This guide walks through deploying a complete cross-chain fleet using the satellite-first approach.

## Overview

Cross-chain fleets allow users to deposit on a hub chain and have assets automatically rebalanced across multiple satellite chains. The deployment follows a **satellite-first** approach to avoid circular dependencies.

## Prerequisites

- Bridge infrastructure deployed on all chains
- Governance contracts deployed on all chains  
- Core contracts deployed on all chains
- Fleet contracts deployed (can be done as part of this process)

## Step-by-Step Deployment

### Step 1: Deploy Bridge Infrastructure

Deploy bridge contracts on both the source (hub) and destination (satellite) chains:

```bash
npx hardhat run scripts/deploy-xchain-core.ts --network optimism
npx hardhat run scripts/deploy-xchain-adapters.ts --network optimism

# On satellite chain (e.g., Base)
npx hardhat run scripts/deploy-xchain-core.ts --network base
npx hardhat run scripts/deploy-xchain-adapters.ts --network base
```

### Step 2: Deploy Satellite Fleet and FleetProxy

Deploy the satellite fleet and FleetProxy on the destination chain:

```bash
# Deploy satellite fleet (if not already deployed)
npx hardhat run scripts/deploy-fleet.ts --network base

# Deploy FleetProxy - this creates Phase 1 of cross-chain config
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network base
```

**What happens:**
- FleetProxy is deployed on the satellite chain
- Cross-chain config file is created in `config/cross-chain/` with Phase 1 data
- FleetProxy address and satellite fleet address are recorded

### Step 3: Deploy Hub Fleet and CrossChainArk

Deploy the hub fleet and CrossChainArk on the source chain:

```bash
# Deploy hub fleet (if not already deployed)
npx hardhat run scripts/deploy-fleet.ts --network optimism

# Deploy CrossChainArk - this updates to Phase 2 config
npx hardhat run scripts/arks/deploy-xchain-ark.ts --network optimism
```

**What happens:**
- CrossChainArk is deployed on the source chain
- Cross-chain config is updated with hub information (Phase 2)
- CrossChainArk address is recorded
- Target proxy is set if FleetProxy address is available

### Step 4: Register Adapter Peers

Register ARK↔FleetProxy peer relationships and executors on both chains:

```bash
# On source chain
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network optimism

# On satellite chain  
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network base
```

**What happens:**
- ARK↔FleetProxy peer relationships are registered in CrossChainRegistry
- CrossChainArk and FleetProxy addresses are registered as authorized executors
- Both chains now know about each other

### Step 5: Verify Setup

Verify that everything is configured correctly:

```bash
# On source chain
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network optimism

# On satellite chain
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network base
```

**What happens:**
- Configuration completeness is checked
- On-chain registry state is verified
- Any mismatches are reported

## Example: Complete Deployment

Here's a complete example deploying a USDC cross-chain fleet from Optimism to Base:

```bash
# 1. Deploy bridge infrastructure
npx hardhat run scripts/deploy-xchain-core.ts --network optimism
npx hardhat run scripts/deploy-xchain-adapters.ts --network optimism
npx hardhat run scripts/deploy-xchain-core.ts --network base  
npx hardhat run scripts/deploy-xchain-adapters.ts --network base

# 2. Deploy satellite components (Base)
npx hardhat run scripts/deploy-fleet.ts --network base
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network base

# 3. Deploy hub components (Optimism)
npx hardhat run scripts/deploy-fleet.ts --network optimism
npx hardhat run scripts/arks/deploy-xchain-ark.ts --network optimism

# 4. Register adapter peers
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network optimism
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network base

# 5. Verify setup
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network optimism
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network base
```

## Adding Additional Destinations

To add more satellite chains to an existing cross-chain fleet:

```bash
# Add new destination to existing config
npx hardhat run scripts/x-chain/post-deployment/add-destination.ts --network arbitrum

# Deploy FleetProxy for new destination
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network arbitrum

# Update CrossChainArk to include new destination (if needed)
npx hardhat run scripts/arks/deploy-xchain-ark.ts --network optimism

# Register adapter peers for new destination
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network arbitrum
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network optimism

# Verify updated setup
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network arbitrum
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network optimism
```

## Configuration Files

Cross-chain configurations are stored in `config/cross-chain/` and evolve through phases:

### Phase 1 (After FleetProxy deployment)
```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "sourceChainId": 0,
  "hubFleetAddress": "",
  "hubFleetName": "",
  "satelliteFleetName": "LazyVault_LowerRisk_USDC",
  "destinations": [
    {
      "chainId": 8453,
      "name": "base",
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x...",
          "crossChainArkAddress": "",
          "satelliteFleetAddress": "0x..."
        }
      ]
    }
  ]
}
```

### Phase 2 (After CrossChainArk deployment)
```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "sourceChainId": 10,
  "hubFleetAddress": "0x...",
  "hubFleetName": "Bummer_SuperLazyVault_LowerRisk_USDC",
  "satelliteFleetName": "LazyVault_LowerRisk_USDC",
  "destinations": [
    {
      "chainId": 8453,
      "name": "base", 
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x...",
          "crossChainArkAddress": "0x...",
          "satelliteFleetAddress": "0x..."
        }
      ]
    }
  ]
}
```

## Troubleshooting

### Common Issues

**"Prerequisites not met"**
- Ensure bridge, governance, and core contracts are deployed
- Run prerequisite scripts first

**"Cross-chain config not found"**
- Deploy FleetProxy first to create Phase 1 config
- Check that you're using the correct fleet name

**"Configuration is incomplete"**
- Follow the satellite-first deployment order
- Complete all phases before registration

**"Relationship already registered"**
- This is normal - the script is idempotent
- Check if the relationship is correct with verify-setup.ts

### Debugging Commands

```bash
# Check current config status
npx hardhat run scripts/deploy-xchain-fleetproxy.ts --network <chain>

# Verify on-chain state
npx hardhat run scripts/x-chain/post-deployment/verify-setup.ts --network <chain>

# Check registry relationships
npx hardhat run scripts/x-chain/post-deployment/register-ark-fleet.ts --network <chain>
```

### Recovery

If something goes wrong:

1. **Check config status** - scripts will show current phase and missing fields
2. **Verify on-chain state** - compare config with registry state
3. **Re-run registration** - scripts are idempotent and safe to re-run
4. **Manual fixes** - edit config files if needed, then re-run verification

## Security Notes

- Always verify addresses before deployment
- Test on testnets before mainnet deployment
- Keep private keys secure during deployment
- Verify all relationships after deployment
- Monitor cross-chain operations after deployment

## Next Steps

After successful deployment:

1. **Monitor operations** - Set up monitoring for cross-chain transfers
2. **Configure keepers** - Ensure keepers are registered as executors
3. **Test rebalancing** - Perform test transfers to verify functionality
4. **Document addresses** - Record all deployed addresses for operations
5. **Set up alerts** - Monitor for failed deliveries and registry changes
