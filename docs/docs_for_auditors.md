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

\```
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

### 2.3 Decay Lifecycle

**Active Period**
- Each account starts with a decay factor of 1.0 (100%)
- The decay-free window (e.g., 30 days) provides protection against short absences
- Any governance action resets the decay timer:
  - Proposing a vote
  - Casting a vote
  - Delegating tokens
  - Canceling a proposal
  - Executing a proposal

**Decay Period**
- After the decay-free window expires:
  - Voting power begins to decay according to the chosen function
  - Rate is configurable (e.g., 5% per month)
  - Continues until minimum threshold or governance action
- Example timeline:
  ```
  Day 0:   Action performed, decay = 1.0
  Day 30:  Decay-free window ends
  Day 60:  Linear: 0.95, Exponential: 0.90
  Day 90:  Linear: 0.90, Exponential: 0.81
  ```

**Delegation Effects**
- Accounts inherit the worst decay factor in their delegation chain
- Maximum delegation depth of 2 to prevent circular dependencies
- Example:
  ```
  Alice (decay: 0.8) → Bob (decay: 0.9) → Carol (decay: 1.0)
  Result: Carol's effective decay = 0.8 (inherited from Alice)
  ```

**Recovery Options**
1. **Governance Participation**
   - Any governance action immediately resets decay to 1.0
   - Requires active participation in protocol governance

2. **New Account Creation**
   - Moving tokens to a fresh address resets decay
   - Loses all delegation history
   - Higher gas costs for setup
   - Must re-establish delegation relationships

3. **Delegation Changes**
   - Can improve decay by delegating to more active accounts
   - Subject to maximum delegation depth
   - Inherits delegate's decay factor

### 2.4 Decay Management
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

### 2.5 Decay Factor Inheritance
The system implements a sophisticated decay inheritance model:

- Accounts inherit the decay factor of their delegate
- Maximum delegation depth of 2 to prevent circular dependencies
- Decay updates cascade through delegation chains
- Delegation changes trigger decay factor recalculation

### 2.6 Integration Points
The decay mechanism integrates with:

- Token transfers and balance checks
- Voting power calculations
- Delegation operations
- Governance proposal creation and voting
- Staking and rewards

### 2.7 Security Considerations
Key security aspects of the decay mechanism:

- Decay factors cannot exceed 1 (100%)
- Protected against underflow in decay calculations
- Delegation depth limit prevents stack overflow
- Atomic updates prevent partial state changes
- Decay-free window protects against short-term inactivity

## 3. Vote Counting and Quorum Mechanics

### 3.1 Vote Counting (GovernorCountingSimple)
The protocol uses OpenZeppelin's simple vote counting system that implements a three-option voting model:

**Vote Types**
- `Against` (0): Opposition votes
- `For` (1): Support votes
- `Abstain` (2): Neutral votes that count toward quorum

**Vote Tracking**
```solidity
struct ProposalVote {
    uint256 againstVotes;
    uint256 forVotes;
    uint256 abstainVotes;
    mapping(address voter => bool) hasVoted;
}
```

**Success Conditions**
- Proposal passes if `forVotes > againstVotes`
- Each address can only vote once per proposal
- Vote weight is determined by decayed voting power
- Votes cannot be changed once cast

### 3.2 Quorum Calculation (GovernorVotesQuorumFraction)
Implements a dynamic quorum system based on total token supply:

**Key Features**
- Quorum is calculated as a fraction of total supply
- Default denominator is 100 (percentages)
- Supports historical quorum lookups
- Can be updated through governance

**Quorum Formula**
```solidity
quorum = (totalSupply * quorumNumerator) / quorumDenominator
```

**Example**
```
Total Supply: 1,000,000 tokens
Quorum Numerator: 4
Quorum Denominator: 100
Required Quorum: 40,000 tokens (4% of total supply)
```

**Quorum Counting**
- Both `For` and `Abstain` votes count toward quorum
- Against votes count for vote result but not quorum
- Uses checkpoints for historical total supply values

### 3.3 Integration with Decay
The vote counting system integrates with the decay mechanism in several ways:

1. **Vote Weight**
   - Raw voting power is multiplied by decay factor
   - Affects both quorum calculation and vote counting
   - Example: 1000 tokens * 0.8 decay = 800 voting power

2. **Quorum Impact**
   - Decay reduces effective voting power
   - May make quorum harder to reach if many voters are inactive
   - Incentivizes active participation to maintain governance functionality

3. **Strategic Considerations**
   - Voters must maintain activity to maximize influence
   - Large holders can't rely on size alone
   - Encourages regular participation in governance

## 4. Access Control

### 4.1 Role-Based Access
The system implements hierarchical access control through:

1. **ProtocolAccessManager**
   - Manages role-based permissions
   - Controls access to critical functions
   - Defines governance roles

2. **TimelockController**
   - Hub chain execution delays
   - Proposal queuing
   - Owner of SummerToken

### 4.2 Cross-Chain Access
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

### 4.3 Satellite Timelock Implementation [TODO]
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

### 4.4 Role Management Security

**Critical Role Considerations:**
- ADMIN_ROLE serves as default admin and guardian for all roles
- PROPOSER_ROLE members can create proposals
- EXECUTOR_ROLE members can execute proposals after delay
- CANCELLER_ROLE members can cancel pending proposals

**Security Recommendations:**
1. **Role Assignment**
   - Minimize number of admin accounts
   - Use multisig or governance for admin role
   - Consider time-locks for role changes
   - Document all role holders and their powers

2. **Execution Delays**
   - Each role member has individual execution delay
   - Operations must be scheduled before execution
   - Delays provide safety window for dangerous operations
   - Consider longer delays for more critical functions

3. **Guardian Powers**
   - Guardians can cancel scheduled operations
   - Critical for emergency response
   - Risk of denial-of-service attacks
   - Consider multi-signature requirements for cancellation

## 5. Token & Voting Power

### 5.1 Voting Power Sources
A delegate's total voting power includes:
- Personal wallet balance
- Vesting contract balance
- Staked tokens in rewards manager
- Delegated voting power from other accounts

### 5.2 Voting Power Calculation
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

### 5.3 Vote Recording System
The voting system uses OpenZeppelin's Checkpoints library to create a historical record of voting power:

- Each delegate has a trace of checkpoints recording their voting power over time
- Checkpoints are created when:
  - Tokens are transferred
  - Delegation changes occur
  - Tokens are minted/burned
- Each checkpoint stores:
  - The block number/timestamp
  - The voting power at that point

### 5.4 Important Considerations for getPastVotes

There is a critical distinction between `getVotes` and `getPastVotes` in SummerToken:

```solidity:packages/gov-contracts/src/contracts/SummerToken.sol
/**
 * @notice Returns the votes for an account at a specific past block, with decay factor applied
 * @param account The address to get votes for
 * @param timepoint The block number to get votes at
 * @return The historical voting power after applying the decay factor
 * @dev This function:
 * 1. Gets the historical raw votes using ERC20Votes' _getPastVotes
 * 2. Applies the current decay factor from VotingDecayManager
 * @custom:relationship-to-votingdecay
 * - Uses VotingDecayManager.getVotingPower() to apply decay
 * - Note: The decay factor is current, not historical
 * - This means voting power can decrease over time even for past checkpoints
 */
function getPastVotes(
    address account,
    uint256 timepoint
) public view override(IVotes, Votes) returns (uint256) {
    return
        decayState.getVotingPower(
            account,
            super.getPastVotes(account, timepoint),
            _getDelegateTo
        );
}
```

#### Key Points:
1. Historical Raw Votes:
   - Uses `super.getPastVotes()` to get the raw voting power at the timepoint
   - This correctly retrieves historical token balances and delegations

2. Current Decay Application:
   - Applies the **current** decay factor via `decayState.getVotingPower()`
   - Does not use historical decay factors
   - Means historical voting power queries are affected by current participation

#### Example Scenario:
```
T0: Account has 1000 tokens, 100% decay factor
    getPastVotes(account, T0) = 1000

T1: Account becomes inactive, decay factor drops to 60%
    getPastVotes(account, T0) = 600  // Same historical point, different result!
```

#### Implications:
- Historical voting power queries don't truly represent past voting power
- The same historical timepoint can return different values as decay changes
- This is intentional to ensure inactive accounts can't leverage historical snapshots
- Systems building on top should be aware that historical analysis may not reflect actual voting power at the time

#### Security Considerations:
- This behavior prevents gaming through historical snapshot selection
- However, it means governance analytics must account for decay factor changes
- Historical voting analysis tools need to track decay factors separately

#### Vote Recording Implementation
While historical queries may be affected by current decay, the actual vote recording properly captures voting power at the time of voting through `_countVote`:

```solidity:packages/gov-contracts/src/contracts/SummerGovernor.sol
/**
 * @dev Override of GovernorCountingSimple._countVote to use decayed voting power
 */
function _countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256,
    bytes memory params
) internal virtual override(Governor, GovernorCountingSimple) returns (uint256) {
    // Get current decayed voting power at time of vote
    uint256 decayedWeight = ISummerToken(address(token())).getVotes(account);

    // Record vote with the decayed weight
    return super._countVote(
        proposalId,
        account,
        support,
        decayedWeight,
        params
    );
}
```

This implementation ensures:
1. Voting power is captured with decay at the moment of voting
2. The weight is permanently recorded in the proposal's vote counts
3. Future decay changes won't affect already-cast votes

#### Comparison of Behaviors

```
Scenario:
T0: Account has 1000 tokens, 100% decay factor
T1: Account casts vote
T2: Account becomes inactive, decay drops to 60%

Different Function Behaviors:
- getPastVotes(account, T0) at T2 = 600  // Historical query affected by current decay
- Actual recorded vote weight at T1 = 1000 // Preserved voting power when cast
```

This distinction is crucial:
- Historical queries (`getPastVotes`) use current decay
- Actual votes record the decay-adjusted power at the moment of voting
- Vote weights, once recorded, are immutable regardless of future decay changes

#### Security Implications:
- Vote weights are correctly preserved in governance history
- Cannot retroactively change the weight of cast votes through decay
- Historical power queries should not be used to audit past votes
- Always refer to the actual recorded vote weights for governance analysis

### 5.5 Voting Power Updates
Voting power changes occur through:
- Token transfers (tracked in `_transferVotingUnits`)
- Delegation changes 
- Decay factor updates
- Vesting contract releases
- Staking/unstaking in rewards manager
- Governance actions (proposing, voting, cancelling etc.) via the `updateDecay` modifier in SummerGovernor.sol

Each of these operations creates new checkpoints to maintain the historical record.

## 6. Integration Points

### 6.1 External Systems
- LayerZero for cross-chain messaging
- OpenZeppelin Governor framework
- Tally.xyz for governance interface

### 6.2 Frontend Integration
The system is partially compatible with Tally.xyz, supporting core governance features:
- Proposal creation interface
- Basic voting mechanisms
- Delegation management

**Important Limitations:**
- Tally has no built in ability (in UI) for showing voting decay over time
- Cross-chain proposal simulations are not supported in the Tally interface

## 7. Known Limitations & Trade-offs

### 7.1 Technical Limitations
- Maximum delegation depth of 2 levels
- Cross-chain message latency
- Gas costs for cross-chain operations
- Historical voting power accuracy with decay

### 7.2 Governance Trade-offs
- Centralization of proposal creation on hub
- Complexity of dual timelock system
- Decay mechanism impact on participation
- Cross-chain execution delays

### 7.3 Integration Constraints
- Limited Tally.xyz compatibility
- LayerZero dependency risks
- Block reorganization protection via LayerZero's ULN pattern
  - While chain reorganizations are a concern in cross-chain systems, LayerZero's Ultra-Light Node (ULN) model provides finality guarantees
  - The protocol leverages LayerZero's configurable block confirmations to ensure message delivery only after sufficient confirmations on source chain
  - This effectively mitigates reorg risks by waiting for practical finality before message delivery
- Gas price volatility impact

### 7.4 Timelock Security Considerations

**Dual Timelock Risks:**
1. **Hub Timelock**
   - Controls all governance operations
   - Self-administered through governance
   - Critical for protocol security
   - Holds protocol assets and permissions

2. **Satellite Timelocks**
   - Execute cross-chain proposals
   - Must sync with hub timelock
   - Potential for timing attacks
   - Cross-chain message validation critical

**Security Recommendations:**
- Maintain minimum delay periods
- Careful

## 8. Critical Contracts

### 8.1 SummerGovernor.sol
The central governance contract that manages the entire protocol's governance system. Key features:

- **Cross-Chain Governance**
  - Hub chain (BASE) creates and executes proposals
  - Uses LayerZero for secure message passing to satellite chains
  - Only hub chain can initiate proposals and voting

- **Proposal Safety Mechanisms**
  - Timelock delay provides window for users to exit before potentially dangerous operations
  - TimelockController acts as execution barrier with configurable delay
  - CANCELLER_ROLE in TimelockController can cancel pending operations
  - [TODO] Exploring enhanced whitelist guardian powers because of the added risk posed by decayed accounts:
    - Allow guardians to cancel proposals with short-term expiration (e.g., 96 hours -> 2 weeks)
    - Limits denial of service risk while providing emergency backstop
    - Must be implemented carefully to prevent abuse of cancellation power
    - Consider requiring multiple guardians to agree for cancellation
    - We just need to be conscious that giving guardians CANCELLER_ROLES opens up the risk of Denial of Service by these trusted persons

- **Voting Power**
  - Implements decay mechanism via DecayController
  - Uses checkpoints for historical vote tracking
  - Supports delegation and vote counting

- **Access Control**
  - Whitelisting system for privileged proposers
  - Timelock integration for execution delays
  - Guardian role for emergency proposal cancellation

- **Key Parameters**
  - MIN_PROPOSAL_THRESHOLD: 1,000 tokens
  - MAX_PROPOSAL_THRESHOLD: 100,000 tokens
  - Configurable voting delay and period
  - Adjustable quorum requirements

#### Core Interface Functions

**Proposal Management**
```solidity
function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256);

function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) external payable returns (uint256);

function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) external returns (uint256);
```

**Cross-Chain Operations**
```solidity
function sendProposalToTargetChain(
    uint32 _dstEid,
    address[] memory _dstTargets,
    uint256[] memory _dstValues,
    bytes[] memory _dstCalldatas,
    bytes32 _dstDescriptionHash,
    bytes calldata _options
) external;
```

**Voting**
```solidity
function castVote(
    uint256 proposalId,
    uint8 support
) external returns (uint256);
```

**Whitelist Management**
```solidity
function setWhitelistAccountExpiration(
    address account,
    uint256 expiration
) external;

function setWhitelistGuardian(
    address _whitelistGuardian
) external;

function isWhitelisted(
    address account
) external view returns (bool);
```

### 8.2 SummerToken.sol
The protocol's governance token implementation, combining voting power, vesting capabilities, and cross-chain functionality. Key features:

- **Voting Power Management**
  - Integrates decay mechanism for inactive holders
  - Aggregates voting power from multiple sources:
    - Direct token balance
    - Staked tokens in rewards manager
    - Tokens in vesting contracts
  - Uses checkpoints for historical vote tracking

- **Cross-Chain Capabilities**
  - Implements LayerZero's OFT (Omnichain Fungible Token)
  - Supports token "teleportation" between chains
  - Maintains consistent voting power across networks

- **Transfer Restrictions**
  - Configurable transfer enable date
  - Whitelist system for early transfers
  - Protected minting and burning operations are available only on teleport

- **Vesting Integration**
  - Custom vesting wallet factory
  - Voting power delegation for vested tokens
  - Maintains beneficiary voting rights during vesting

#### Core Interface Functions

**Voting Power**
```solidity
function getVotes(
    address account
) external view returns (uint256);

function getPastVotes(
    address account,
    uint256 timepoint
) external view returns (uint256);

function delegate(
    address delegatee
) external;
```

**Decay Management**
```solidity
function setDecayRatePerSecond(
    uint256 newRatePerSecond
) external;

function setDecayFreeWindow(
    uint40 newWindow
) external;

function getDecayFactor(
    address account
) external view returns (uint256);
```

**Transfer Control**
```solidity
function enableTransfers() external;

function addToWhitelist(
    address account
) external;

function removeFromWhitelist(
    address account
) external;
```

**Key Parameters**
- Implements ERC20 with extensions (Permit, Votes, Capped)
- Configurable maximum supply
- Adjustable decay parameters
- Customizable transfer restrictions

### 8.3 GovernanceRewardsManager.sol
The staking and rewards management contract that handles governance token staking and reward distribution. Key features:

- **Staking Management**
  - Handles staking of governance tokens
  - Tracks user balances and total staked amounts
  - Integrates with voting power calculations
  - Supports staking on behalf of other addresses

- **Rewards System**
  - Supports multiple reward tokens
  - Implements smoothed decay factor for rewards
  - Uses exponential moving average (EMA) for decay calculations
  - Rewards are adjusted based on user's decay factor

- **Decay Integration**
  - Smoothing factor of 0.2 (20%) for decay calculations
  - Maintains smoothed decay factors per user
  - Affects reward earnings based on participation
  - Updates decay factors during stake/unstake operations

- **Key Parameters**
  - DECAY_SMOOTHING_FACTOR: 0.2e18 (20%)
  - DECAY_SMOOTHING_FACTOR_BASE: 1e18 (100%)
  - Configurable reward rates per token
  - Protected staking/unstaking operations

#### Core Interface Functions

**Staking Operations**
```solidity
function stake(
    uint256 amount
) external;

function stakeOnBehalfOf(
    address receiver,
    uint256 amount
) external;

function unstake(
    uint256 amount
) external;
```

**Rewards Management**
```solidity
function earned(
    address account,
    IERC20 rewardToken
) external view returns (uint256);

function balanceOf(
    address account
) external view returns (uint256);

function updateSmoothedDecayFactor(
    address account
) external;
```

**Key Formulas**
```solidity
// Smoothed Decay Factor Calculation (EMA)
smoothedFactor = (currentDecayFactor * DECAY_SMOOTHING_FACTOR + 
                 previousSmoothedFactor * (BASE - DECAY_SMOOTHING_FACTOR)) / BASE;

// Adjusted Rewards Calculation
adjustedRewards = rawEarned * smoothedDecayFactor / WAD;
```

#### Exponential Moving Average (EMA) Decay Smoothing

The contract implements EMA smoothing for decay factors to create a more stable and predictable rewards system:

**Purpose**
- Prevents sudden drops in rewards due to sharp changes in decay factors
- Creates a "memory" of user participation history
- Smooths out reward fluctuations while maintaining incentive alignment
- Protects against gaming through short-term participation

**Implementation**
```solidity
smoothedFactor = (currentDecayFactor * DECAY_SMOOTHING_FACTOR + 
                 previousSmoothedFactor * (BASE - DECAY_SMOOTHING_FACTOR)) / BASE;
```

Where:
- `DECAY_SMOOTHING_FACTOR = 0.2e18` (20%)
- `BASE = 1e18` (100%)
- New value is weighted 20% current + 80% historical

**Example Scenario**
1. User has perfect participation (decay = 1.0) for a long time
   - Smoothed decay ≈ 1.0
2. User becomes inactive (decay drops to 0.6)
   - First update: 0.92 = (0.6 * 0.2) + (1.0 * 0.8)
   - Second update: 0.856 = (0.6 * 0.2) + (0.92 * 0.8)
   - Continues gradually approaching 0.6

This creates a "soft landing" for rewards rather than cliff-like drops, while still maintaining long-term incentive alignment with participation.

## 9. Upgrade Procedures

### 9.1 Contract Upgrades
- All upgrades must be approved through governance vote
- Changes are executed via timelock controller
- Emergency upgrades follow standard governance process

### 9.2 Parameter Updates
All parameter modifications require governance proposals and include:
- Governance parameter modification (voting periods, thresholds, quorum)
- Decay mechanism tuning (rates, windows, calculation methods)
- Cross-chain configuration changes (gas limits, confirmation blocks)
- Reward rate adjustments
- Whitelist management

Each parameter update follows the standard governance flow:
1. Proposal creation on hub chain
2. Voting period
3. Timelock delay
4. Execution
5. Cross-chain propagation (if applicable)

### 9.3 Chain Addition/Removal
**Chain Addition**
- Peering is handled during satellite deployment creation
- Process typically involves:
  1. Deployment of satellite contracts
  2. LayerZero endpoint configuration
  3. Cross-chain messaging setup
  4. Initial governance parameter synchronization

**Chain Deprecation**
- Current approach is minimal:
  1. Block new token deposits to the chain
  2. Gradually unwind existing positions and fleets
  3. Leave deployment dormant but accessible
- Future considerations needed for:
  - Formal deprecation proposals
  - Token bridge shutdown procedures
  - Historical data preservation
  - User communication guidelines
