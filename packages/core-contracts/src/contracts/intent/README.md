# Intent-Based Bond System

## Overview

The Intent-Based Bond System is a CoW Swap-style bonding mechanism where **each solver creates their own individual bond contract** via a factory. The system uses a generic Ark that posts intents offchain, and solvers solve them directly without needing Ark approval.

## Architecture

### System Components

- **GenericIntentArk**: Generic Ark that posts intents and can cancel them before solving
- **IntentBondFactory**: Factory that creates individual bond contracts for each solver
- **SolverBond**: Individual bond contract per solver (Summer tokens only)
- **IntentHandler**: Manages intent lifecycle and bond verification
- **Protocol Adapters**: Handle specific protocol interactions (Aave V3, etc.)

## Flow Diagram

```mermaid
flowchart TD
    %% Actors
    User[👤 User/Ark Commander]
    Solver[🤖 Solver]
    Ark[🏴‍☠️ Generic Intent Ark]
    Factory[🏭 Intent Bond Factory]
    Bond[💰 Solver's Individual Bond]
    Handler[⚙️ Intent Handler]
    Adapter[🔌 Protocol Adapter]
    Protocol[🌊 External Protocol]
    
    %% Solver Bond Creation Flow
    Solver -->|1. Create Bond| Factory
    Factory -->|2. Deploy Bond Contract| Bond
    Factory -->|3. Record Bond| Factory
    
    %% Intent Creation Flow
    User -->|4. Post Intent| Ark
    Ark -->|5. Record Intent| Handler
    Handler -->|6. Create Intent| Handler
    
    %% Intent Solving Flow
    Solver -->|7. Solve Intent| Handler
    Handler -->|8. Check Bond via Factory| Factory
    Factory -->|9. Return Bond Contract| Handler
    Handler -->|10. Verify Bond Amount| Bond
    Bond -->|11. Bond Sufficient| Handler
    Handler -->|12. Mark Solved| Handler
    
    %% Intent Execution Flow
    Solver -->|13. Activate Intent| Handler
    Handler -->|14. Mark Active| Handler
    Solver -->|15. Execute via Adapter| Adapter
    Adapter -->|16. Protocol Call| Protocol
    
    %% Intent Settlement Flow
    Solver -->|17. Complete Term| Handler
    Solver -->|18. Settle Intent| Handler
    Handler -->|19. Mark Settled| Handler
    
    %% Alternative Flows
    User -->|20a. Cancel Intent| Ark
    Ark -->|21a. Resign Intent| Handler
    Handler -->|22a. Mark Cancelled| Handler
    
    Solver -->|20b. Resign Intent| Handler
    Handler -->|21b. Get Bond Contract| Factory
    Factory -->|22b. Return Bond Contract| Handler
    Handler -->|23b. Slash Bond 50%| Bond
    Bond -->|24b. Update Bond| Bond
    
    %% Styling
    classDef userClass fill:#e1f5fe,stroke:#01579b,stroke-width:2px
    classDef solverClass fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef arkClass fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef contractClass fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px
    classDef protocolClass fill:#fce4ec,stroke:#880e4f,stroke-width:2px
    
    class User userClass
    class Solver solverClass
    class Ark arkClass
    class Factory,Bond,Handler,Adapter contractClass
    class Protocol protocolClass
```

## Detailed Flow Steps

### 1. Solver Bond Creation
- **Solver** calls `IntentBondFactory.createBond(solver)`
- **Factory** deploys new `SolverBond` contract for that solver
- **Factory** records the mapping of solver → bond contract
- **Solver** now has their own isolated bond contract

### 2. Intent Creation
- **User/Commander** posts intent with requirements (notional, term, yield, etc.)
- **GenericIntentArk** records the intent on-chain
- **IntentHandler** creates intent in `Created` state

### 3. Intent Solving
- **Solver** sees intent and calls `solveIntent()` directly
- **IntentHandler** checks if solver has bond contract via factory
- **IntentHandler** verifies solver has sufficient bond in their individual contract
- Intent transitions to `Solved` state

### 4. Intent Execution
- **Solver** activates intent (starts the term)
- **Solver** executes protocol actions via adapter
- **Protocol Adapter** handles specific protocol interactions

### 5. Intent Settlement
- **Solver** completes the term and settles intent
- Intent transitions to `Settled` state
- **Solver** keeps their bond in their individual contract

### 6. Alternative Paths
- **Ark can cancel** intent before solving (only in `Created` state)
- **Solver can resign** intent (50% bond penalty from their individual contract)

## Key Features

- ✅ **Individual bond contracts** per solver (complete isolation)
- ✅ **Factory pattern** for easy bond creation
- ✅ **Generic Ark** handles any protocol via adapters
- ✅ **Offchain intent posting** - Ark just records
- ✅ **Direct solver execution** - no Ark approval bottlenecks
- ✅ **Summer token bonds only** - simple and clean
- ✅ **50% penalty** for solver resignations

## Contract Interactions

```mermaid
graph LR
    subgraph "Intent System"
        Ark[GenericIntentArk]
        Handler[IntentHandler]
        Factory[IntentBondFactory]
    end
    
    subgraph "Individual Bonds"
        Bond1[Solver1 Bond]
        Bond2[Solver2 Bond]
        BondN[SolverN Bond]
    end
    
    subgraph "Protocol Layer"
        Adapter[AaveV3Adapter]
        Protocol[Aave V3 Pool]
    end
    
    subgraph "External"
        Solver1[Solver 1]
        Solver2[Solver 2]
        Summer[Summer Token]
    end
    
    Ark --> Handler
    Handler --> Factory
    Factory --> Bond1
    Factory --> Bond2
    Factory --> BondN
    Solver1 --> Bond1
    Solver2 --> Bond2
    Solver1 --> Handler
    Solver2 --> Handler
    Solver1 --> Adapter
    Adapter --> Protocol
    Bond1 --> Summer
    Bond2 --> Summer
```

## State Transitions

```mermaid
stateDiagram-v2
    [*] --> Created: postIntent()
    Created --> Solved: solveIntent()
    Created --> ResignedByArk: cancelIntent()
    Solved --> Active: activateIntent()
    Active --> Settled: settleIntent()
    Active --> ResignedBySolver: resignBySolver()
    Solved --> ResignedBySolver: resignBySolver()
    
    note right of Created
        Intent posted by Ark
        Waiting for solver
    end note
    
    note right of Solved
        Solver has solved intent
        Bond verified via factory
    end note
    
    note right of Active
        Intent is executing
        Term is running
    end note
    
    note right of Settled
        Intent completed successfully
        Solver keeps bond in their contract
    end note
```

## Benefits

1. **Complete Isolation**: Each solver has their own bond contract
2. **Factory Pattern**: Easy to create new bonds for new solvers
3. **Minimal Code**: Clean separation of concerns
4. **Overly Simple**: Easy to understand and maintain
5. **CoW Swap Style**: Individual bonding pools per solver
6. **Generic Design**: One Ark handles any protocol
7. **Efficient Flow**: No approval bottlenecks
8. **Flexible**: Easy to add new protocols via adapters

## How It Works

1. **Solver creates bond**: `factory.createBond(solver)` → deploys `SolverBond` contract
2. **Ark posts intent** with requirements (notional, term, yield, etc.)
3. **Solver solves intent** directly by calling `solveIntent()`
4. **System verifies** solver has sufficient bond in their individual contract
5. **Solver executes** via protocol adapter (Aave, etc.)
6. **Solver settles** when term completes
7. **Bond stays** in solver's individual contract (no shared pools)

This is **exactly like CoW Swap's bonding pools** - each solver has their own pool, they're completely isolated, and they can solve intents directly without waiting for Ark approval.

The system is now **minimal as possible** and **overly simple** as requested! 🎉
