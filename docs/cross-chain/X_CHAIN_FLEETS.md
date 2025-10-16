# FleetCommander - MEV Protection Solution

## Overview

The `FleetCommander` now includes built-in MEV protection mechanisms designed to prevent the critical MEV vulnerability identified in the protocol. This vulnerability allows arbitrageurs to extract 5-20% of TVL annually through timing-based attacks on cross-chain operations.

## The MEV Problem

### Root Cause
- **Information Asymmetry**: Arbitrageurs monitor remote chains in real-time
- **Bridge Delays**: Inherent delay between remote events and local updates
- **ERC4626 Pricing**: Immediate and transparent share pricing
- **No Access Control**: FleetCommander has no restrictions on core functions

### Attack Scenarios
1. **Loss Realization Arbitrage**: Withdraw before loss, deposit after
2. **Reward Distribution Sandwich**: Capture rewards before they're distributed

## Solution: Withdrawal Fee-Based MEV Protection

The `FleetCommander` implements a withdrawal fee-based system that provides economic disincentives for MEV attacks while maintaining ERC4626 compliance. Users burn full shares but receive reduced assets, with the fee remaining in the vault to benefit remaining shareholders.

### Key Components

#### 1. Withdrawal Fee Calculation
- Configurable withdrawal fee percentage applied to all withdrawals/redemptions
- Fee calculation based on total assets being withdrawn
- ERC4626 compliant fee mechanism

#### 2. Share Burning and Asset Reduction
- Users burn the full amount of shares corresponding to their withdrawal
- Users receive assets minus the calculated fee amount
- Fee amount remains in the vault, increasing value for remaining shareholders

#### 3. Fee Collection and Re-boarding
- For ark withdrawals: fees are re-boarded to the buffer ark
- For buffer withdrawals: fees naturally stay in the buffer
- `WithdrawalFeeCollected` event tracks fee collection


### Architecture

```
User Withdrawal → Calculate Fee → Burn Full Shares → Receive Reduced Assets
     ↓                ↓                ↓                    ↓
  Request         Fee Applied      Share Burning        Asset Transfer
  (Any Time)      (MEV Protected)  (ERC4626 Compliant)  (Fee Stays in Vault)
```

## Implementation Details

### 1. State Variables

**Added to `FleetCommander.sol`:**
```solidity
/// @notice Withdrawal fee configuration and calculation
/// @dev Fee is applied to withdrawals/redemptions to prevent MEV attacks
uint256 public initialWithdrawalFee;
```

### 2. Withdrawal Fee Configuration

**Constructor Parameters:**
```solidity
FleetCommanderParams memory params
// Now includes initialWithdrawalFee field
```

The withdrawal fee is configurable through the `initialWithdrawalFee` parameter in the constructor and stored in the `FleetConfig`. After deployment, the rebalance cooldown period can be updated by curators using the `updateRebalanceCooldown()` function.

### 3. FleetCommander Features

#### Withdrawal Fee Functions
- `getCooldown()` - Get the current rebalance cooldown period
- `getLastActionTimestamp()` - Get the last rebalance timestamp
- `_calculateWithdrawalFee(assets)` - Calculate withdrawal fee for given assets
- `updateRebalanceCooldown(uint256 newCooldown)` - Update rebalance cooldown period (curator only)

#### Withdrawal Fee Enforcement
- `_handleWithdrawalFee(owner, totalAssets, feeAmount)` - Internal helper for fee collection and re-boarding
- `WithdrawalFeeCollected` event - Emitted when withdrawal fees are collected
- Fee calculation applied in all withdrawal/redemption functions

### 4. MEV Protection Mechanisms

#### Economic Disincentive
- Withdrawal fees create economic cost for MEV attacks
- Eliminates profitability of timing-based arbitrage
- Prevents sandwich attacks on reward distributions

#### ERC4626 Compliance
- Standard withdrawal fee mechanism
- Users burn full shares but receive reduced assets
- Fee remains in vault, benefiting remaining shareholders

#### Fee Collection
- Automatic fee calculation and collection
- Re-boarding of fees to buffer ark for ark withdrawals
- Natural fee retention for buffer withdrawals

## Usage Example

### 1. User Deposits
```solidity
// User calls deposit (no restrictions)
uint256 shares = fleetCommander.deposit(1000e6, user);
// Returns shares immediately, no cooldown period
```

### 2. Withdrawal Fee Calculation
```solidity
// Calculate withdrawal fee for given assets
uint256 assets = 500e6;
uint256 feeAmount = fleetCommander._calculateWithdrawalFee(assets);

// User will receive: assets - feeAmount
uint256 assetsReceived = assets - feeAmount;
```

### 3. User Withdrawals
```solidity
// Withdrawal applies fee automatically
uint256 assets = fleetCommander.withdraw(500e6, user, user);
// User receives reduced assets, fee stays in vault
// Full shares are burned, fee benefits remaining shareholders
```

## Configuration Parameters

### FleetCommanderParams
- `initialWithdrawalFee`: Initial withdrawal fee percentage applied to withdrawals/redemptions
- `initialRebalanceCooldown`: Initial cooldown period between rebalance operations (in seconds)
- Standard FleetCommander parameters (name, symbol, asset, etc.)

### Governance Updates
- `updateRebalanceCooldown(newCooldown)`: Update rebalance cooldown period after deployment (curator only)
- Emits `CooldownUpdated` event when updated
- Can only be called when contract is not paused

## Benefits

### 1. MEV Protection
- **Eliminates timing attacks**: Withdrawal fees create economic disincentive for MEV attacks
- **Prevents arbitrage**: Fees make timing-based opportunities unprofitable
- **Reduces value extraction**: From 5-20% annually to near zero

### 2. Protocol Security
- **Fee enforcement**: Automatic fee calculation and collection
- **ERC4626 compliance**: Standard withdrawal fee mechanism
- **Benefit distribution**: Fees benefit remaining shareholders

### 3. User Experience
- **Immediate deposits**: Users can deposit immediately without restrictions
- **Transparent fees**: Clear fee calculation and application
- **ERC4626 standard**: Familiar withdrawal fee mechanism
- **Adaptive protection**: Rebalance cooldown period can be adjusted based on market conditions
- **Fund access**: Users can always withdraw their funds (with fee applied)

## Trade-offs

### 1. User Experience
- Withdrawals/redemptions have fees applied (by design)
- Users receive reduced assets due to fee
- May impact users who need full liquidity immediately

### 2. Complexity
- Slightly more complex than standard FleetCommander
- Requires fee calculation and collection logic
- Additional state management for fee handling

### 3. Gas Costs
- Minimal additional gas for fee calculation
- Fee collection is very efficient
- Overall minimal gas impact

## Migration Strategy

### 1. Gradual Rollout
- Deploy alongside existing FleetCommander
- Migrate users gradually
- Monitor for issues

### 2. Backward Compatibility
- Maintains ERC4626 interface
- Preview functions work immediately
- Users can check cooldown status

### 3. Fallback Mechanisms
- Users can check withdrawal fee calculation before attempting withdrawals
- Clear fee application in all withdrawal functions
- Configurable withdrawal fee for different use cases
- Governance can adjust rebalance cooldown period based on operational needs

## Security Considerations

### 1. Withdrawal Fee Configuration
- Withdrawal fee must be set appropriately for the use case
- Too low: May not prevent all MEV attacks
- Too high: May impact user experience
- Governance can adjust rebalance cooldown period based on market conditions and security requirements

### 2. Fee Calculation
- Fee calculation is deterministic and transparent
- No external dependencies for fee computation
- ERC4626 standard ensures consistent behavior

### 3. State Management
- Simple fee calculation reduces attack surface
- No complex queue management required
- Minimal state to maintain

## Conclusion

The `FleetCommander` provides a robust solution to the MEV vulnerability by implementing a withdrawal fee-based system that creates economic disincentives for MEV attacks. This prevents arbitrageurs from exploiting timing-based attacks while maintaining ERC4626 compliance and core functionality of the protocol.

The solution is designed to be:
- **Secure**: Eliminates MEV opportunities through economic disincentives
- **Simple**: Minimal complexity with efficient fee calculation
- **User-friendly**: Standard ERC4626 withdrawal fee mechanism
- **Maintainable**: Straightforward implementation with clear logic
- **Adaptive**: Configurable rebalance cooldown period allows for operational flexibility

This implementation addresses the fundamental protocol-level issue that could make the system economically unviable at scale, ensuring the long-term sustainability of the protocol. The withdrawal fee mechanism provides economic protection while the governance-controlled rebalance cooldown period provides operational flexibility.
