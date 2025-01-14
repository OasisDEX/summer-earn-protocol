# Summer Rewards Distribution System

This package contains the smart contracts and scripts for managing Summer's token reward distributions using Merkle trees.

## Overview

The system consists of two main components:
1. `SummerRewardsRedeemer.sol` - Smart contract for managing and claiming rewards
2. `generate-merkle-root.ts` - Script for generating Merkle trees from distribution data

## Directory Structure

```
packages/rewards-contracts/
├── distributions/           # Distribution data files
│   ├── 1/                  # Ethereum Mainnet
│   │   └── 1.json         # Distribution #1
│   ├── 10/                # Optimism
│   ├── 137/               # Polygon
│   ├── 8453/              # Base
│   └── 42161/             # Arbitrum One
├── merkle-trees/           # Generated Merkle tree data
│   ├── 1/
│   ├── 10/
│   └── ...
├── scripts/
│   └── generate-merkle-root.ts
└── src/contracts/
    └── SummerRewardsRedeemer.sol
```

## Distribution Files

Each distribution file should be a JSON file with the following format:
```json
{
  "0x1234...": "1000000000000000000",
  "0x5678...": "2000000000000000000"
}
```
Where:
- Keys are Ethereum addresses
- Values are token amounts in wei (as strings)

## Usage

### 1. Generate Merkle Tree

```bash
pnpm generate-merkle-root
```

This interactive script will:
1. Prompt you to select a chain (displays friendly names like "Base" instead of "8453")
2. Prompt you to select a distribution file
3. Generate a Merkle tree and save it to `merkle-trees/<chainId>/distribution-<number>.json`

The generated file contains:
```json
{
  "chainId": "8453",
  "distributionId": "1",
  "merkleRoot": "0x...",
  "totalAmount": "1000000000000000000000",
  "addressCount": 100,
  "claims": {
    "0x1234...": {
      "amount": "10000000000000000000",
      "proof": ["0x...", "0x...", "0x..."]
    }
  }
}
```

### 2. Deploy Contract

Deploy `SummerRewardsRedeemer` with:
- `_rewardsToken`: Address of the token to distribute
- `_accessManager`: Address of Summer's access manager

### 3. Add Merkle Root

Using the governance system, call `addRoot(uint256 index, bytes32 root)` with:
- `index`: Distribution number (e.g., 1 for first distribution)
- `root`: Merkle root from the generated JSON file

### 4. Users Claim Rewards

Users can claim their rewards in several ways:

```solidity
// Single claim
function claim(
    uint256 index,
    uint256 amount,
    bytes32[] calldata proof
) external;

// Multiple claims at once
function claimMultiple(
    uint256[] calldata indices,
    uint256[] calldata amounts,
    bytes32[][] calldata proofs
) external;
```

Users can check their claim status:
```solidity
function canClaim(
    uint256 index,
    uint256 amount,
    bytes32[] memory proof
) external view returns (bool);

function hasClaimed(
    address user,
    uint256 index
) public view returns (bool);
```

## Contract Features

### Governance Functions
- `addRoot(uint256 index, bytes32 root)`: Add a new distribution
- `removeRoot(uint256 index)`: Remove a distribution
- `emergencyWithdraw(address token, address to, uint256 amount)`: Emergency withdrawal

### User Functions
- `claim`: Claim rewards for a single distribution
- `claimMultiple`: Claim rewards from multiple distributions at once
- `canClaim`: Check if a claim is possible
- `hasClaimed`: Check if rewards were already claimed

### Security Features
- Double-hashed leaves to prevent second preimage attacks
- Safe ERC20 transfers
- Governance-controlled root management
- Bitmap-based claim tracking
- Protection against duplicate claims

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
pnpm test
```

## License
BUSL-1.1