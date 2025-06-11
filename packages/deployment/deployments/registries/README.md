# CrossChainRegistry Deployments

This directory contains deployment configuration files for the CrossChainRegistry contract across all supported networks.

## Overview

The CrossChainRegistry is a centralized registry that manages cross-chain relationships between CrossChainArk and FleetProxy contracts. It provides the following functionality:

- Register ark-proxy relationships with target chain IDs
- Query proxy addresses for given arks
- Query ark addresses for given proxies and source chains
- Validate ark-proxy pairs
- Manage relationship status (active/inactive)

## Deployment Files

Each network has a simple deployment file that tracks the registry address:

- `CrossChainRegistry_mainnet_deployment.json` - Ethereum Mainnet
- `CrossChainRegistry_base_deployment.json` - Base
- `CrossChainRegistry_arbitrum_deployment.json` - Arbitrum One
- `CrossChainRegistry_sonic_deployment.json` - Sonic

### File Structure

```json
{
  "contractName": "CrossChainRegistry",
  "registryAddress": "0x...",
  "network": "mainnet"
}
```

## Deployment Methods

### 1. Integrated Deployment (Part of Core Contracts)

Deploy as part of the core protocol contracts:

```bash
npx hardhat run scripts/deploy-core.ts --network mainnet
```

This will deploy all core contracts including the CrossChainRegistry.

### 2. Standalone Deployment (Registry Only)

Deploy only the CrossChainRegistry:

```bash
npx hardhat run scripts/deploy-registry.ts --network mainnet
```

This is useful for:
- Upgrading only the registry
- Deploying to new networks
- Testing registry functionality

## Constructor Parameters

The CrossChainRegistry deployment automatically uses:

1. **`_accessManager`**: Retrieved from the network config (`config.deployedContracts.gov.protocolAccessManager.address`)
2. **`_currentChainId`**: Automatically determined from the current network

No manual configuration of these parameters is needed - they're pulled from your existing network configurations.

## Network Support

| Network | Chain ID | Status |
|---------|----------|--------|
| Mainnet | 1 | ✅ Supported |
| Base | 8453 | ✅ Supported |
| Arbitrum | 42161 | ✅ Supported |
| Sonic | 146 | ✅ Supported |

## Usage After Deployment

Once deployed, the CrossChainRegistry can be used to:

1. **Register Ark-Proxy Relationships** (Governor only):
   ```solidity
   registry.registerArkProxy(arkAddress, targetChainId, proxyAddress);
   ```

2. **Query Relationships**:
   ```solidity
   // Get proxy for an ark
   (address proxy, uint16 chainId) = registry.getProxyForArk(arkAddress);
   
   // Get ark for a proxy
   address ark = registry.getArkForProxy(sourceChainId, proxyAddress);
   
   // Validate ark-proxy pair
   bool isValid = registry.isValidArkProxyPair(ark, chainId, proxy);
   ```

3. **Manage Status** (Governor only):
   ```solidity
   registry.updateRelationshipStatus(arkAddress, isActive);
   ```

## Access Control

The CrossChainRegistry uses the protocol's access control system:

- **Governor Role**: Can register/unregister ark-proxy relationships and update status
- **Public Read**: Anyone can query relationships and validate pairs

## Events

The contract emits the following events:

- `ArkProxyRegistered(address ark, uint16 targetChainId, address proxy)`
- `ArkProxyUnregistered(address ark, uint16 targetChainId, address proxy)`
- `RelationshipStatusUpdated(address ark, bool isActive)`
- `RegistryInitialized(uint16 currentChainId)` 