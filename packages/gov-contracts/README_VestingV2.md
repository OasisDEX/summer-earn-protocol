# Summer Vesting Wallet V2

This document describes the new Summer Vesting Wallet V2 contracts that implement the internally controlled vesting system with enhanced features and flexibility.

## Overview

The V2 vesting system addresses the new requirements for internally controlled vesting contracts that will be managed by the Oazo Multisig. These contracts use a simple ownership model where the factory is owned by the deployer initially, who then transfers ownership to the multisig. The vesting wallets check the factory owner for admin permissions, providing a clean and simple access control mechanism.

## Key Features

### 1. Configurable Cliff Period
- **Cliff End Date**: Instead of a fixed 180-day cliff, the cliff end date is configurable via Unix timestamp
- **Cliff Amount**: Custom amount of tokens to vest at the cliff end date
- **Example**: Set cliff to end on September 1st, 2025 (`1756681200`) with 2,000,006 SUMR tokens

### 2. Configurable Time-Based Vesting
- **Vesting Periods**: Configurable number of monthly periods after cliff
- **Total Amount**: Custom total amount to vest over the periods
- **Monthly Distribution**: Each period vests `totalVestingAmount / vestingPeriods` tokens
- **Cliff + Performance Only**: Set both `vestingPeriods = 0` and `totalVestingAmount = 0` for cliff + performance-only vesting
- **Example**: 5,999,994 SUMR over 18 months = 333,333 SUMR per month

### 3. Enhanced Performance Criteria
- **Custom Amounts**: Each performance goal can have different token amounts
- **Custom Descriptions**: Human-readable descriptions for each goal (e.g., "500M TVL", "100,000 active users")
- **Dynamic Goals**: Goals can be added after contract creation
- **Flexible Tracking**: Goals are tracked by index (0-based) for easy management

### 4. Enhanced Recall Functionality
- **All-remaining tokens recall**: Can recall all tokens
- **One-Time Operation**: Recalled tokens cannot be recalled again


## Contract Architecture

### Core Contracts
1. **SummerVestingWalletV2**: The main vesting wallet implementation
2. **SummerVestingWalletFactoryV2**: Factory for creating new vesting wallets
3. **ISummerVestingWalletV2**: Interface defining the wallet functionality
4. **ISummerVestingWalletFactoryV2**: Interface defining the factory functionality

### Key Structs

```solidity
struct VestingParams {
    uint64 cliffEndTimestamp;    // Unix timestamp when cliff ends
    uint256 cliffAmount;         // Amount to vest at cliff
    uint256 vestingPeriods;      // Number of monthly periods after cliff
    uint256 totalVestingAmount;  // Total amount to vest over periods
}

struct PerformanceGoal {
    uint256 amount;              // Token amount for this goal
    string description;          // Human-readable description
    bool reached;                // Whether the goal has been reached
}
```

## Usage Example

Based on the hypothetical example from the requirements:

```solidity
// Setup vesting parameters
ISummerVestingWalletV2.VestingParams memory params = ISummerVestingWalletV2.VestingParams({
    cliffEndTimestamp: 1756681200,  // September 1st, 2025
    cliffAmount: 2000006 ether,     // 2,000,006 SUMR at cliff
    vestingPeriods: 18,             // 18 monthly periods
    totalVestingAmount: 5999994 ether // 5,999,994 SUMR over 18 months
});

// Setup performance goals
ISummerVestingWalletV2.PerformanceGoal[] memory goals = new ISummerVestingWalletV2.PerformanceGoal[](2);
goals[0] = ISummerVestingWalletV2.PerformanceGoal({
    amount: 1000000 ether,
    description: "500M TVL",
    reached: false
});
goals[1] = ISummerVestingWalletV2.PerformanceGoal({
    amount: 1000000 ether,
    description: "100,000 active users", 
    reached: false
});

// Create vesting wallet (only Foundation can call)
address vestingWallet = factory.createVestingWallet(
    beneficiaryAddress,
    params,
    goals
);
```

## Access Control

The V2 system uses a simple ownership model:

1. **Factory Owner**: The factory is deployed with an initial owner (deployer)
2. **Ownership Transfer**: The deployer transfers ownership to the Oazo Multisig
3. **Vesting Wallet Admin**: Each vesting wallet checks the factory owner for admin permissions

## Admin Functions

All admin functions require being the factory owner (Oazo Multisig):

1. **addNewGoal(amount, description)**: Add new performance goals
2. **markGoalReached(goalIndex)**: Mark performance goals as reached
3. **recallUnvestedTokens()**: Recall both time-based and performance-based unvested tokens

## Vesting Schedule

The vesting schedule works as follows:

1. **Before Cliff**: No tokens are vested
2. **At Cliff End**: `cliffAmount` tokens vest immediately
3. **After Cliff**: Each month, `totalVestingAmount / vestingPeriods` tokens vest (if vestingPeriods > 0)
4. **Performance Goals**: Tokens vest immediately when goals are marked as reached
5. **Total**: Maximum vestable = `cliffAmount + totalVestingAmount + sum(reached performance goals)`

### Special Cases

- **Cliff + Performance Only**: Set `vestingPeriods = 0` and `totalVestingAmount = 0` to create a vesting contract with only cliff and performance-based vesting
- **Invalid Configuration**: Having `totalVestingAmount > 0` with `vestingPeriods = 0` will revert (cannot distribute positive amount over zero periods)

## Migration from V1

The V2 contracts are completely independent from V1 contracts. Key differences:

| Feature | V1 | V2 |
|---------|----|----|
| Cliff Period | Fixed 180 days | Configurable timestamp |
| Cliff Amount | Proportional | Configurable amount |
| Vesting Duration | Fixed 2 years | Configurable periods |
| Performance Goals | Amount only | Amount + description |
| Recall | Performance only | Both time & performance |
| Goal Management | 1-indexed | 0-indexed |

## Testing

Comprehensive tests are provided in:
- `test/vesting/SummerTokenVestingV2.t.sol`: Main vesting wallet tests
- `test/vesting/SummerTokenVestingFactoryV2.t.sol`: Factory tests

The tests cover all major scenarios including:
- Configurable cliff and vesting periods
- Performance goals with descriptions
- Recall functionality for both token types
- Edge cases and error conditions
- Integration with the access control system

## Deployment Workflow

1. **Deploy Factory**: Deploy `SummerVestingWalletFactoryV2` with deployer as initial owner
2. **Create Vesting Wallets**: Use factory to create vesting wallets for beneficiaries
3. **Transfer Ownership**: Transfer factory ownership to Oazo Multisig
4. **Manage Vesting**: Multisig can now manage all vesting wallets created by the factory

## Deployment Considerations

1. **Simple Ownership**: Uses standard OpenZeppelin Ownable for clean access control
2. **Token Compatibility**: Works with any ERC20 token (designed for SUMR)
3. **Gas Optimization**: Monthly periods use 30-day constants for consistent gas costs
4. **Upgradability**: Contracts are not upgradeable; new versions require redeployment
5. **Delegation**: Maintains compatibility with existing governance delegation system
6. **Factory Pattern**: Single factory can create multiple vesting wallets, all controlled by the same owner 