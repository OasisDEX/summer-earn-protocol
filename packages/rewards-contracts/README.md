# Summer Rewards Distribution System

This package contains the smart contracts for managing Summer's token reward distributions using Merkle trees.

## Overview

The system uses `SummerRewardsRedeemer.sol` - a smart contract for managing and claiming rewards through a Merkle-based distribution system.

## Directory Structure

```
packages/rewards-contracts/
└── src/contracts/
    └── SummerRewardsRedeemer.sol
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

## Usage

### 1. Deploy Contract

Deploy `SummerRewardsRedeemer` with:
- `_rewardsToken`: Address of the token to distribute
- `_accessManager`: Address of Summer's access manager

### 2. Add Merkle Root

Using the governance system, call `addRoot(uint256 index, bytes32 root)` with:
- `index`: Distribution number (e.g., 1 for first distribution)
- `root`: Merkle root from the generated JSON file

### 3. Users Claim Rewards

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