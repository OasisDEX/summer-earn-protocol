# Cross-Chain Ark Architecture Plan

## Overview
This document outlines the architecture for creating a unified multi-chain USDC fleet system using Cross-Chain Arks.

## Goals
- Create a unified liquidity experience across multiple chains
- Maintain fair representation of deposits across chains
- Minimize cross-chain messaging costs while maintaining accurate state
- Ensure reliable performance as the system scales
- Provide seamless user experience regardless of the chain they interact with

## Basic Architecture

### Current Model (Point-to-Point)
Chain A: USDC Fleet A
- Cross Chain Ark pointing at Fleet USDC B
- Cross Chain Ark pointing at Fleet USDC C

Chain B: USDC Fleet B
- Cross Chain Ark pointing at Fleet USDC A
- Cross Chain Ark pointing at Fleet USDC C

Chain C: USDC Fleet C
- Cross Chain Ark pointing at Fleet USDC A
- Cross Chain Ark pointing at Fleet USDC B

### Components
1. **Cross-Chain Ark**: Special Ark deployed on each chain that represents a neighboring chain's fleet
2. **Cross-Chain Ark Proxy**: Component on target chain that receives bridged assets and interacts with the local fleet
3. **Bridge Router**: Infrastructure handling the cross-chain communication

## Functionality Flow

1. **Asset Transfer & Bridging**
   - Assets are transferred to a Cross-Chain Ark on Chain A
   - These assets are bridged to Chain B via the bridge router
   - A Cross-Chain Ark Proxy on Chain B receives the assets and deposits them into Fleet B

2. **State Synchronization**
   - Cross-Chain Ark on Chain A periodically reads state from Fleet B (via Cross-Chain Ark Proxy)
   - This state information is used to correctly represent the portion of assets held on the other chain
   - State reads trigger bridge messaging costs

## Cross-Chain Withdrawal Strategies

The core challenge: Users deposit in Fleet A but want to withdraw from Fleet B, despite having no direct shares in Fleet B.

### Option 1: Cross-Chain Share Verification and Redemption
1. **User Initiates Cross-Chain Withdrawal**:
   - User requests withdrawal from Fleet B where they have no shares
   - They specify their address and withdrawal amount

2. **Cross-Chain Verification**:
   - Fleet B sends a cross-chain message to Fleet A
   - Message verifies user's balance in Fleet A and locks/burns shares

3. **Release of Funds**:
   - Upon confirmation, Fleet B releases equivalent funds to user

**Pros:** True cross-chain experience, seamless UX
**Cons:** Expensive messaging, high latency, requires sufficient liquidity

### Option 2: Facilitated Bridge Withdrawal
1. **Integrated Withdrawal + Bridge UI**:
   - Presents as single action to user
   - Behind scenes: withdraw from original fleet, bridge to target chain

2. **Fleet-Integrated Bridging**:
   - Automatic bridging after withdrawal
   - Optimized for fast bridge solutions

**Pros:** Simpler implementation, more capital efficient
**Cons:** Not a true single-transaction experience, bridge waiting time

### Hybrid Approach: Instant Withdrawals with Asynchronous Settlement
1. **Cross-Chain Liquidity Reserves**:
   - Each fleet maintains reserves for cross-chain withdrawals
   - Users get instant withdrawals on any chain

2. **Behind-the-Scenes Settlement**:
   - System periodically rebalances cross-chain positions
   - User shares from original chain are eventually redeemed

## Yield Normalization Subtleties

### Asymmetric Cross-Chain Positions
When Chain A has 20% of assets in Chain B, but Chain B only has 5% in Chain A:
- Updates from Chain B → Chain A are more critical for fair yield calculation
- Chain A depositors are more impacted by stale data than Chain B depositors

### Adaptive Update Framework
To optimize for asymmetric positions:

1. **Priority-Based Updates**
   - **High Priority**: Cross-chain positions >10% of fleet assets
   - **Medium Priority**: Positions 3-10% of assets
   - **Low Priority**: Positions <3% of assets

2. **Update Frequency Factors**
   - **Absolute Value**: Larger USD positions get more frequent updates
   - **Relative Percentage**: Higher portion of source fleet gets priority
   - **Activity Level**: More active fleets need more frequent updates

3. **Cost-Efficiency Mechanisms**
   - **Weighted Budgeting**: Allocate messaging budget by position size
   - **Threshold-Based Updates**: Different staleness thresholds by significance
   - **State Change Triggers**: Update when metrics change significantly

## Challenges & Considerations

### Efficiency & Cost Trade-offs
- **Messaging Frequency**: More frequent updates mean higher costs but more accurate representation
- **Increasing Costs with Scale**: As the number of interconnected fleets grows, point-to-point messaging becomes increasingly expensive
- **Gas Optimization**: Need to balance cost of cross-chain reads with the benefits of updated state

### Fairness to Depositors
- State synchronization frequency directly impacts fair representation of depositors across chains
- Delays in updates could lead to temporary misrepresentation of total assets
- Need to determine optimal frequency based on:
  * Cost of cross-chain messaging
  * Rate of deposit/withdrawal activity
  * Acceptable staleness of data

### Scaling Concerns
- The current point-to-point model results in O(n²) communication complexity as chains increase
- Each fleet needs to maintain state with every other fleet
- Costs become prohibitive at scale

## Potential Solutions

### Keeper-Managed Updates
- Implement keeper logic to determine optimal timing for state updates
- Parameters to consider:
  * Time since last update
  * Estimated change in state since last update
  * Current gas costs for cross-chain messaging
  * Value of assets under management (larger pools justify more frequent updates)

### Hub and Spoke Model
- As scale increases, transition to a hub-and-spoke architecture:
  * Designate one chain as the "hub" for state aggregation
  * Each "spoke" chain reports state changes to the hub
  * Hub broadcasts aggregate state to all spokes
- Reduces communication complexity from O(n²) to O(n)
- Potential single point of failure, but more economically sustainable at scale

### Layered Update Frequency
- Implement tiered update frequencies:
  * High-frequency updates for critical state changes
  * Medium-frequency updates for significant but non-critical changes
  * Low-frequency full-state synchronization

## Next Steps
- Implement prototype of Cross-Chain Ark and Proxy
- Develop simulation to analyze cost vs. accuracy trade-offs at different scales
- Design and implement keeper logic for optimizing update frequency
- Determine thresholds for potential transition to hub-and-spoke model
- Create specification for cross-chain withdrawal mechanism implementation
- Simulate asymmetric position scenarios to refine update strategy


