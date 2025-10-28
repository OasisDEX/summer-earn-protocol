# Cross-Chain Configuration

This directory contains configuration files that define cross-chain relationships between hub and satellite fleets.

## Configuration Format

Each JSON file defines a cross-chain fleet topology with the following structure:

```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "sourceChainId": 10,
  "hubFleetAddress": "0x05Da9eE95BF7f0a37e79a1341706eFB65e385979",
  "hubFleetName": "Bummer_SuperLazyVault_LowerRisk_USDC",
  "satelliteFleetName": "LazyVault_LowerRisk_USDC",
  "destinations": [
    {
      "chainId": 8453,
      "name": "chain-8453",
      "protocols": [
        {
          "protocol": "summerfi",
          "fleetProxyAddress": "0x6bDCf1dCAd15e11D7d7B90F5b017aB1fc049dC0f",
          "crossChainArkAddress": "0x5f311c931e03217aa0eae99eaF15A7b33543Ec75",
          "satelliteFleetAddress": "0x98C49e13bf99D7CAd8069faa2A370933EC9EcF17"
        }
      ]
    }
  ]
}
```

## Field Descriptions

- `fleetName`: Name of the cross-chain fleet configuration
- `sourceChainId`: Chain ID of the hub chain (where the main fleet is deployed)
- `hubFleetAddress`: Address of the hub fleet on the source chain
- `hubFleetName`: Name of the hub fleet
- `satelliteFleetName`: Name of the satellite fleets on destination chains
- `destinations`: Array of destination chain configurations
  - `chainId`: Chain ID of the destination chain
  - `name`: Human-readable name for the destination chain
  - `protocols`: Array of protocol configurations for this destination
    - `protocol`: Protocol name (e.g., "summerfi")
    - `fleetProxyAddress`: Address of the FleetProxy on the destination chain
    - `crossChainArkAddress`: Address of the CrossChainArk on the source chain
    - `satelliteFleetAddress`: Address of the satellite fleet on the destination chain

## Usage

These configuration files are used by:

1. `register-ark-fleet.ts` - Registers ARK↔FleetProxy relationships in the CrossChainRegistry
2. `register-executors.ts` - Registers authorized executors (CrossChainArk/FleetProxy addresses)
3. Cross-chain deployment scripts that need to know the topology

## Example Workflow

1. Deploy hub fleet on source chain (e.g., Optimism)
2. Deploy satellite fleets on destination chains (e.g., Base, Unichain)
3. Deploy CrossChainArk on source chain
4. Deploy FleetProxies on destination chains
5. Create cross-chain config file with all addresses
6. Run `register-ark-fleet.ts` on each chain to register relationships
7. Run `register-executors.ts` on each chain to authorize executors