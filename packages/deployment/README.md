# Summer Protocol Deployment Package

This package contains deployment scripts and Merkle tree generation tools for the Summer protocol.

## Overview

The package handles two main functionalities:
1. Protocol Deployment Scripts (Core, Governance, and Fleet systems)
2. Merkle Tree Generation for Rewards Distribution

## Directory Structure

```
packages/deployment/
├── ignition/
│   └── modules/
│       ├── core.ts       # Core protocol module
│       ├── gov.ts        # Governance module
│       └── fleet.ts      # Fleet module
├── scripts/
│   ├── deploy-core.ts    # Core deployment script
│   ├── deploy-gov.ts     # Governance deployment script
│   ├── deploy-fleet.ts   # Fleet deployment script
│   └── generate-merkle-root.ts
└── token-distributions/
    ├── input/
    └── output/
```

## Deployment System

### 1. Governance Deployment (`deploy-gov`)

Deploys the governance system in the following order:
1. ProtocolAccessManager
2. TimelockController
3. SummerToken
4. SummerGovernor
5. RewardsRedeemer

```bash
NETWORK=<network> pnpm deploy:gov
```

Key Parameters:
- Initial token supply
- Voting delay: 60 seconds (testing)
- Voting period: 600 seconds (testing)
- Proposal threshold: 10,000 SUMMER
- Quorum fraction: 4%

### 2. Core Protocol Deployment (`deploy-core`)

Deploys core protocol components:
1. Core Infrastructure
   - DutchAuctionLibrary
   - ConfigurationManager
2. Protocol Components
   - TipJar
   - FleetCommanderRewardsManagerFactory
3. Main Protocol Contracts
   - HarborCommand
   - Raft
4. Supporting Contracts
   - AdmiralsQuarters

```bash
NETWORK=<network> pnpm deploy:core
```

### 3. Fleet Deployment (`deploy-fleet`)

Deploys individual fleet instances:
1. FleetCommander contract
2. Associated Arks
3. Configuration setup

```bash
NETWORK=<network> pnpm deploy:fleet
```

### Supported Networks

- Arbitrum One (42161)
- Base (8453)
- Other networks as configured

## Deployment Commands

```bash
# Deployment Commands
pnpm deploy:gov              # Deploy governance system
pnpm deploy:core             # Deploy core protocol
pnpm deploy:fleet            # Deploy fleet system
pnpm deploy:ark              # Deploy individual ark
pnpm deploy:buy-and-burn     # Deploy buy and burn system

# Deployment Status
pnpm deploy:status:arbitrum  # Check Arbitrum deployment status
pnpm deploy:status:base      # Check Base deployment status

# Verification
pnpm verify:arbitrum         # Verify contracts on Arbitrum
pnpm verify:base             # Verify contracts on Base

# Visualization
pnpm visualize:core          # Visualize deployment dependencies
```

## Merkle Tree Generation

For reward distribution management, see [Merkle Tree Generation](#merkle-tree-generation) section below.

### Input Format

Place distribution files in `token-distributions/input/{chainId}/merkle-redeemer/`:

```json
{
  "0xuser1...": "1000000000000000000",
  "0xuser2...": "2000000000000000000"
}
```

### Output Format

Generated in `token-distributions/output/{chainId}/merkle-redeemer/`:

```json
{
  "chainId": "1",
  "distributionId": "1",
  "merkleRoot": "0x...",
  "totalAmount": "3000000000000000000",
  "addressCount": 2,
  "claims": {
    "0xuser1...": {
      "amount": "1000000000000000000",
      "proof": ["0x...", "0x..."]
    }
  }
}
```

### Usage

```bash
pnpm generate-merkle-root
```

## Development

### Prerequisites
- Node.js 16+
- pnpm
- Foundry (for contract testing)

### Setup
```bash
pnpm install
```

### Testing
```bash
pnpm coverage        # Run coverage tests
pnpm coverage:lcov   # Generate LCOV report
pnpm coverage:report # Generate HTML coverage report
```

## License
BUSL-1.1 

## Fleet Deployment System

### 1. Fleet Configuration Files

Fleet configurations are JSON files located in `config/fleets/` that define the fleet parameters and its associated Arks.

Example fleet configuration (`config/fleets/usdc-base-USDC-1.json`):
```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "symbol": "LVUSDC",
  "assetSymbol": "USDC",
  "initialMinimumBufferBalance": "0",
  "initialRebalanceCooldown": "3600",
  "depositCap": "1000000000",
  "initialTipRate": "0",
  "network": "base",
  "details": "",
  "arks": [
    {
      "type": "AaveV3Ark",
      "params": {
        "asset": "USDC",
        "protocol": "aaveV3"
      }
    },
    // Additional Arks...
  ]
}
```

Configuration Parameters:
- `fleetName`: Unique identifier for the fleet
- `symbol`: Token symbol for the fleet
- `assetSymbol`: Underlying asset symbol (e.g., "USDC")
- `initialMinimumBufferBalance`: Minimum balance to maintain in buffer
- `initialRebalanceCooldown`: Time between rebalances (in seconds)
- `depositCap`: Maximum total deposits allowed
- `initialTipRate`: Initial fee rate for the fleet
- `network`: Target network for deployment
- `arks`: Array of Ark configurations
  - `type`: Type of Ark to deploy
  - `params`: Ark-specific parameters

### 2. Deployment Process

```bash
NETWORK=base pnpm deploy:fleet
```

The deployment script will:
1. Prompt you to select a fleet configuration file
2. Deploy the FleetCommander contract
3. Deploy all configured Arks
4. Set up necessary permissions and configurations

### 3. Deployment Output

After successful deployment, a JSON file is created in `deployments/fleets/` with the deployed contract addresses.

Example deployment file (`deployments/fleets/LazyVault_LowerRisk_USDC_base_deployment.json`):
```json
{
  "fleetName": "LazyVault_LowerRisk_USDC",
  "fleetSymbol": "LVUSDC",
  "assetSymbol": "USDC",
  "fleetAddress": "0x3d34EC4588BAe77AfBbd894c5BeB6d53958b161D",
  "bufferArkAddress": "0x776373D6D4f84160C34364851f131e63EBF20d42",
  "network": "base",
  "initialMinimumBufferBalance": "0",
  "initialRebalanceCooldown": "3600",
  "depositCap": "1000000000",
  "initialTipRate": "0",
  "arks": [
    "0x125dAE47930c1118cf2dB5A140877C64B408783C",
    // Additional Ark addresses...
  ]
}
```

Deployment Output Fields:
- Original configuration parameters
- `fleetAddress`: Deployed FleetCommander contract address
- `bufferArkAddress`: Deployed BufferArk contract address
- `arks`: Array of deployed Ark contract addresses

### 4. Supported Ark Types

The following Ark types can be configured:
- `AaveV3Ark`: For Aave V3 protocol integration
- `CompoundV3Ark`: For Compound V3 protocol integration
- `ERC4626Ark`: For ERC4626-compliant vaults
- `MorphoVaultArk`: For Morpho protocol vaults
- `SkyUsdsPsm3Ark`: For Sky protocol integration 