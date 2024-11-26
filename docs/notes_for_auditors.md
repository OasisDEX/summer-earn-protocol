# Summer Protocol Governance - Technical Documentation

## 1. System Architecture

### 1.1 Hub and Spoke Model
The Summer Protocol implements a cross-chain governance system with BASE as the central authority. This model consists of:

- **Hub Chain (BASE)**
  - Central authority for all governance actions
  - Houses the TimelockController
  - Controls token supply and distribution
  - All proposals created and voted here

- **Satellite Chains**
  - Execute-only nodes
  - Zero initial token supply
  - Tokens only minted via "teleportation" from hub
  - No direct proposal creation or voting capabilities

### 1.2 Cross-Chain Communication
The protocol uses LayerZero for secure cross-chain messaging. The typical proposal flow is:

\```mermaid
flowchart TD
    A["Proposal Created on Hub (BASE)"] --> B["Voting Delay Passes"]
    B --> C["Voting Begins"]
    C --> D["Voting Period Expires"]
    D --> E["Proposal Queued with Timelock Controller"]
    E --> F["Proposal Executed on Hub"]
    F --> G["Message Transmitted via LayerZero"]
    G --> H["Message Received by SummerGovernor on Satellite"]
    H --> I["Proposal Executed on Satellite"]
\```

### 1.3 Satellite Chain Execution [TODO]
- Implement timelock scheduling for received proposals on satellite chains
- Allow permissionless execution of scheduled proposals
- Ensure synchronization of timelock delays between hub and satellites
- Consider gas optimization for multiple proposal executions

### 1.4 Standard vs Cross-Chain Governance Comparison

| Component | OpenZeppelin Governor | Summer Protocol |
|-----------|---------------------|-----------------|
| **Architecture** | Single chain, monolithic | Hub and spoke model with BASE as central authority |
| **Proposal Creation** | Direct proposal submission | Proposals only created on hub chain |
| **Voting** | Single chain voting | Voting only on hub chain |
| **Execution Flow** | 1. Proposal created<br>2. Voting period<br>3. Queue in timelock<br>4. Execute | 1. Proposal created on hub<br>2. Voting period on hub<br>3. Queue in hub timelock<br>4. Execute on hub<br>5. LayerZero message to satellites<br>6. Queue in satellite timelock<br>7. Execute on satellites |
| **Timelock** | Single timelock controller | Dual timelock structure:<br>- Primary timelock on hub<br>- Secondary timelocks on satellites |
| **Token Supply** | Single chain token management | - Hub: Full token supply<br>- Satellites: "Teleported" tokens only |
| **Access Control** | Standard OZ AccessControl | Two-tier structure:<br>- Hub: Full governance capabilities<br>- Satellites: Execute-only permissions |

Key Implementation Differences:

## 2. Novel Decay Mechanism

### 2.1 Overview
The protocol implements a novel voting power decay mechanism that dynamically adjusts voting power based on participation:

- Voting power decays over time when accounts are inactive
- Both direct token holders and their delegators are affected by decay
- Governance activities reset the decay timer
- Configurable decay-free window protects against short-term inactivity
- Decay factors are inherited through delegation chains (max depth: 2)

### 2.2 Decay Implementation
Two decay functions are available:

1. **Linear Decay**
   - Simple linear reduction over time: `power = initialPower * (1 - rate * time)`
   - Predictable, constant rate of decay
   - More forgiving for medium-term inactivity
   - Implemented in `VotingDecayMath.linearDecay()`

2. **Exponential Decay**
   - Accelerating decay over time: `power = initialPower * (1 - rate)^time`
   - Compounds the reduction in voting power
   - More aggressive incentive for regular participation
   - Implemented in `VotingDecayMath.exponentialDecay()`

### 2.3 Decay Management
The decay system is managed through several interconnected components:

1. **DecayController**
   - Abstract contract inherited by governance contracts
   - Coordinates decay updates between token and rewards
   - Provides `updateDecay` modifier for governance actions
   - Ensures synchronized decay state across system

2. **VotingDecayLibrary**
   - Core implementation of decay logic
   - Manages per-account decay factors
   - Handles delegation chain traversal
   - Maintains decay parameters:
     - `decayFreeWindow`: Grace period before decay begins
     - `decayRatePerSecond`: Rate of power loss
     - `decayFunction`: Linear or Exponential

3. **VotingDecayMath**
   - Low-level mathematical calculations
   - Uses PRBMath for precise fixed-point arithmetic
   - Implements both decay formulas
   - Handles overflow protection

### 2.4 Decay Factor Inheritance
The system implements a sophisticated decay inheritance model:

- Accounts inherit the decay factor of their delegate
- Maximum delegation depth of 2 to prevent circular dependencies
- Decay updates cascade through delegation chains
- Delegation changes trigger decay factor recalculation

### 2.5 Integration Points
The decay mechanism integrates with:

- Token transfers and balance checks
- Voting power calculations
- Delegation operations
- Governance proposal creation and voting
- Staking and rewards

### 2.6 Security Considerations
Key security aspects of the decay mechanism:

- Decay factors cannot exceed 1 (100%)
- Protected against underflow in decay calculations
- Delegation depth limit prevents stack overflow
- Atomic updates prevent partial state changes
- Decay-free window protects against short-term inactivity

## 3. Access Control

### 3.1 Role-Based Access
The system implements hierarchical access control through:

1. **ProtocolAccessManager**
   - Manages role-based permissions
   - Controls access to critical functions
   - Defines governance roles

2. **TimelockController**
   - Hub chain execution delays
   - Proposal queuing
   - Owner of SummerToken

### 3.2 Cross-Chain Access
The system implements a two-tier timelock structure:

1. **Hub Chain (BASE)**
   - Full governance capabilities with TimelockController
   - Primary timelock schedules proposals
   - Controls proposal creation and voting
   - Initiates cross-chain execution messages

2. **Satellite Chains**
   - Secondary timelock controllers for execution
   - Receive and schedule proposals from hub
   - Permissionless execution after delay
   - No direct proposal creation

### 3.3 Satellite Timelock Implementation [TODO]
Satellite chains should implement a timelock system that:

1. **Message Reception**
   - Receives LayerZero messages from hub
   - Validates proposal parameters
   - Schedules execution in local timelock

2. **Execution Flow**
   ```mermaid
   flowchart TD
       A["Message Received from Hub"] --> B["Validate Message Source"]
       B --> C["Extract Proposal Data"]
       C --> D["Schedule in Satellite Timelock"]
       D --> E["Wait for Delay Period"]
       E --> F["Allow Permissionless Execution"]
   ```

## 4. Token & Voting Power

### 4.1 Voting Power Sources
A delegate's total voting power includes:
- Personal wallet balance
- Vesting contract balance
- Staked tokens in rewards manager
- Delegated voting power from other accounts

### 4.2 Voting Power Calculation
The token implements a custom `_getVotingUnits` that aggregates voting power from multiple sources:

```solidity
function _getVotingUnits(address account) internal view returns (uint256) {
    // Get raw voting units first
    uint256 directBalance = balanceOf(account);
    uint256 stakingBalance = rewardsManager.balanceOf(account);
    uint256 vestingBalance = vestingWalletFactory.vestingWallets(account) != address(0)
        ? balanceOf(vestingWalletFactory.vestingWallets(account))
        : 0;

    return directBalance + stakingBalance + vestingBalance;
}
```

This means an account's voting units include:
- Direct token balance
- Tokens staked in the rewards manager
- Tokens in vesting contracts

### 4.3 Vote Recording System
The voting system uses OpenZeppelin's Checkpoints library to create a historical record of voting power:

- Each delegate has a trace of checkpoints recording their voting power over time
- Checkpoints are created when:
  - Tokens are transferred
  - Delegation changes occur
  - Tokens are minted/burned
- Each checkpoint stores:
  - The block number/timestamp
  - The voting power at that point

### 4.4 Important Considerations for getPastVotes

There is a critical distinction between `getVotes` and `getPastVotes`:

1. `getVotes(address)`:
   - Returns current voting power
   - Applies current decay factor
   - Accurately reflects current voting strength

2. `getPastVotes(address, timepoint)`:
   - Returns historical voting power
   - BUT applies the CURRENT decay factor
   - This means historical voting power queries may be inaccurate

#### Potential Implications:
- Governance systems using `getPastVotes` should be aware that the returned value doesn't truly represent the voting power at that historical point
- The actual historical voting power might have been higher if decay has increased since then
- This could affect:
  - Vote counting accuracy
  - Historical voting analysis
  - Governance power calculations

### 4.5 Voting Power Updates
Voting power changes occur through:
- Token transfers (tracked in `_transferVotingUnits`)
- Delegation changes 
- Decay factor updates
- Vesting contract releases
- Staking/unstaking in rewards manager
- Governance actions (proposing, voting, cancelling etc.) via the `updateDecay` modifier in SummerGovernor.sol

Each of these operations creates new checkpoints to maintain the historical record.

## 5. Integration Points

### 5.1 External Systems
- LayerZero for cross-chain messaging
- OpenZeppelin Governor framework
- Tally.xyz for governance interface

### 5.2 Frontend Integration
The system is compatible with Tally.xyz, providing:
- Proposal creation interface
- Voting mechanisms
- Delegation management
- Power tracking

## 6. Security Considerations

### 6.1 Cross-Chain Security
- Message validation
- Execution authorization
- State synchronization
- Reorg protection

### 6.2 Critical Parameters
- Decay rates
- Voting thresholds
- Timelock periods
- Cross-chain gas limits