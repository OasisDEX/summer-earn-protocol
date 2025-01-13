# Summer Governance Contracts

This package contains the core governance contracts for the Summer protocol.

## Main Contracts

### SummerGovernor.sol

`SummerGovernor` is the main governance contract for the Summer protocol. It extends various OpenZeppelin governance modules and includes custom functionality such as whitelisting and voting decay.

Key features:
- Cross-chain proposal execution
- Whitelisting system for proposers
- Integration with LayerZero for cross-chain messaging
- Custom voting power calculation with decay

### SummerToken.sol

`SummerToken` is the governance token for the Summer protocol. It extends OpenZeppelin's ERC20 implementation and includes additional features.

Key features:
- ERC20 with voting capabilities
- Integration with LayerZero's OFT (Omnichain Fungible Token)
- Built-in vesting wallet creation

### SummerVestingWallet.sol

`SummerVestingWallet` is a custom vesting wallet implementation for the Summer protocol.

Key features:
- Two vesting schedules: 6-month cliff and 2-year quarterly vesting
- Built on top of OpenZeppelin's VestingWallet

## Understanding Decayed Voting Power

The Summer protocol implements a unique voting decay mechanism where voting power gradually decreases over time unless actively managed. Here's how it works:

### Core **Concepts**

1. **Decay Rate**: A configurable rate (between 1% and 50% per year / TBD) at which voting power decreases
2. **Decay-Free Window**: An initial period (between 1 day and 180 days / TBD) where no decay occurs
3. **Delegation Chain**: A maximum of 2 levels of delegation are allowed before voting power is zeroed out
4. **Checkpoints**: Records of voting power at specific points in time

### Example Scenarios

#### Scenario 1: Basic Decay

Alice holds 1000 SUMMER tokens and self-delegates:
```
T+0:   Alice self-delegates
       Initial voting power = 1000
       Decay checkpoint created with factor = 1.0 (WAD)

T+30d: Still within decay-free window
       Voting power = 1000 (no decay)

T+395d: After 1 year (including decay-free window)
       Voting power ≈ 900 (10% decay applied)
```

#### Scenario 2: Delegation Chain

Bob has 1000 SUMMER tokens and delegates through a chain:
```
T+0:   Bob delegates to Charlie
       Charlie delegates to Alice
       Valid chain (depth = 2)
       Bob's tokens contribute to Alice's voting power

T+0:   If Alice then delegates to Dave
       Chain becomes: Bob -> Charlie -> Alice -> Dave
       Voting power = 0 (exceeds MAX_DELEGATION_DEPTH)
```

#### Scenario 3: Resetting Decay

Charlie wants to reset their decay factor:
```
1. Create new wallet
2. Transfer tokens to new wallet
3. Delegate from new wallet
   - New decay checkpoint created
   - Decay factor reset to WAD (1.0)
   - New decay-free window begins
```

### Best Practices

1. **Active Management**
   - Regularly update your delegation to refresh decay factors
   - Consider re-delegating before important votes

2. **Delegation Strategy**
   - Keep delegation chains short (max 2 levels)
   - Monitor your current decay factor using `getDecayFactor()`

3. **Decay Protection**
   - Use the decay-free window strategically
   - Create new wallets for fresh decay factors when needed
   - Consider splitting holdings across multiple addresses to manage decay risk

### Technical Details

- Decay is calculated using either linear or exponential functions
- Historical voting power uses current decay factors (not historical ones)
- Checkpoints are created on:
  - Initial delegation
  - Token transfers
  - Decay factor updates
  - Delegation changes

### Important Notes

1. **Irreversible**: Decay cannot be reversed without using a new wallet
2. **Compound Effect**: Long delegation chains can result in zero voting power
3. **Checkpoint Impact**: All voting power calculations use the current decay factor, even for historical queries

### Understanding Delegation vs Decay Inheritance

A critical distinction exists between how voting power and decay factors are handled in delegation chains:

#### Voting Power Flow
```
Alice (1000 SUMMER) -> Bob -> Charlie
Result: Charlie has 1000 voting power
        Bob has 0 voting power
        Alice has 0 voting power
```

#### Decay Factor Inheritance (Reverse Flow)
```
Alice (holder) -> Bob -> Charlie (final delegate)
Result: Alice's decay factor = Charlie's decay factor
        If Charlie is inactive, Alice's rewards decay
        If Bob changes delegate, Alice's decay follows the new chain
```

### Why This Matters

1. **Voting Power**
   - Flows forward through the delegation chain
   - Only the final delegate can use the voting power
   - Previous delegates in the chain have zero voting power

2. **Decay Factor**
   - Inherited backwards through the delegation chain
   - Token holders (like Alice) are affected by their delegate's inactivity
   - Used for both voting power AND rewards calculation
   - Encourages choosing active delegates

### Example Scenario

```
T+0:   Alice holds 1000 SUMMER
       Delegates to Bob, who delegates to Charlie
       All decay factors = 1.0 (WAD)

T+60d: Charlie becomes inactive
       Charlie's decay factor begins decreasing
       Alice's rewards also decay, even though she's active
       Because: Alice inherits Charlie's decay factor

T+90d: Bob changes delegate to Dave (active user)
       Alice's decay factor now follows Dave
       Alice's rewards begin to recover
```

### Strategic Implications

1. **For Token Holders**
   - Monitor your delegate's activity
   - Your rewards depend on your delegate's engagement
   - Consider direct delegation to active participants

2. **For Delegates**
   - Maintain regular activity to prevent decay
   - Communicate delegation changes to your delegators
   - Understand you affect your delegators' reward rates

## Foundry

This project uses Foundry, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Usage

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```

#### Format

```shell
$ forge fmt
```

#### Gas Snapshots

```shell
$ forge snapshot
```

#### Anvil (Local Ethereum node)

```shell
$ anvil
```

#### Deploy

```shell
$ forge script script/DeployGovernance.s.sol:DeployGovernanceScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

#### Cast (Contract interaction)

```shell
$ cast <subcommand>
```

#### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Documentation

For more detailed information about Foundry, visit: https://book.getfoundry.sh/

### Audits

- [ChainSecurity](./audits/chainsecurity-audit.pdf)
