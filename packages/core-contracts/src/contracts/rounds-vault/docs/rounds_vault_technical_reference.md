# Rounds Vault & Institutional Ark — Technical Reference

> Complete technical documentation for the async settlement architecture used by offchain RWA (and future Benji-token-style) integrations.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Contract Hierarchy](#2-contract-hierarchy)
3. [Token Model: Receipts (ERC-1155 NFTs)](#3-token-model-receipts-erc-1155-nfts)
4. [Round State Machine](#4-round-state-machine)
5. [Input Vault (Deposit Flow)](#5-input-vault-deposit-flow)
6. [Output Vault (Withdrawal Flow)](#6-output-vault-withdrawal-flow)
7. [Exchange Rate Math](#7-exchange-rate-math)
8. [T+1 Ark Internals](#8-t1-ark-internals)
9. [Keeper Operations Playbook](#9-keeper-operations-playbook)
10. [Entry Point Analysis](#10-entry-point-analysis)
11. [Systemic Risks & Operational Limitations](#11-systemic-risks-and-operational-limitations)

-----

## 1\. Architecture Overview

The Rounds Vault system solves a fundamental problem: institutional tokenized funds (e.g. offchain RWA: WTGXX, CRDYX, and future Benji tokens) have **locked investment periods** where deposits/withdrawals are processed in T+0 or T+1 off-chain settlement cycles. Users cannot interact directly during these periods.

The Rounds Vault acts as an **asynchronous buffering layer** between users and the unified FleetCommander ERC-4626 vault, utilizing a **Two-Phase Settlement** model to securely isolate on-chain deposits from off-chain NAV execution.

```mermaid
flowchart LR
    U[User] -->|deposit USDC| IV[RoundsVaultInput]
    IV -->|"1. nextRound() \n2. setRoundSettled()"| FC[FleetCommander]
    FC -->|"board()"| ARK[T+1 Ark]
    ARK -->|USDC wire| WT[offchain RWA\nOff-Chain]
    WT -->|shares| ARK
    ARK -.->|totalAssets ↑| FC
    FC -.->|previewDeposit| IV
    IV -->|exchange receipts| U2[User receives\nFleet shares]

    U3[User] -->|deposit Fleet shares| OV[RoundsVaultOutput]
    OV -->|"1. nextRound() \n2. setRoundSettled()"| FC2[FleetCommander]
    FC2 -->|"disembark()"| ARK2[T+1 Ark]
    ARK2 -->|shares wire| WT2[offchain RWA\nOff-Chain]
    WT2 -->|USDC| ARK2
    ARK2 -.->|sweep → buffer| FC2
    OV -->|exchange receipts| U4[User receives USDC]
```

-----

## 2\. Contract Hierarchy & Access Control

The protocol uses a centralized **ProtocolAccessManagerV2** to maintain a single source of truth for whitelisting and Operator roles. The `Whitelist` contract is a stateless adapter that forwards checks to the central manager.

```mermaid
classDiagram
    class ProtocolAccessManagerV2 {
        -_whitelisted : mapping
        +isWhitelisted(account) bool
        +setWhitelisted(account, allowed)
        +grantOperatorRole(target, account)
    }

    class WhitelistProxy {
        <<abstract>>
        #_getAccessManager() address
        +isWhitelisted(account) bool
        +setWhitelisted(account, allowed)
    }

    class RoundsVaultBase {
        -_roundNumber : uint256
        +nextRound() [Keeper]
        +setRoundSettled(roundId) [Keeper]
        +deposit(assets, receiver) [Whitelisted]
        +redeemExchangeAsset() [Whitelisted]
    }
    
    class FleetCommander {
        +isOperatorGatewayOpen : bool
        +transfersEnabled : bool
        +deposit() [Gateway Enforced]
        +withdraw() [Gateway Enforced]
    }

    ProtocolAccessManagerV2 <-- WhitelistProxy : Delegates queries/state
    WhitelistProxy <|-- RoundsVaultBase
    WhitelistProxy <|-- FleetCommander
    RoundsVaultBase <|-- RoundsVaultInput
    RoundsVaultBase <|-- RoundsVaultOutput
```

-----

## 3\. Token Model: Receipts (ERC-1155 NFTs)

When a user deposits into a Rounds Vault, they do **not** receive ERC-20 shares. Instead they receive **ERC-1155 receipt tokens** where:

| Property | Value |
|----------|-------|
| Token standard | ERC-1155 |
| Token ID | `_roundNumber` at time of deposit |
| Amount | 1:1 with deposited assets (same decimals) |
| Transferable | Yes (standard ERC-1155 transfer) |
| Redeemable for deposit token | Only current round via `redeem()` |
| Exchangeable for exchange asset | Only past settled rounds via `redeemExchangeAsset()` |

### Receipt lifecycle

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Minted: User calls deposit()
    Minted --> CurrentRound: Round N is open

    CurrentRound --> Redeemable: User can redeem()\ngets deposit token back
    CurrentRound --> Locked: Keeper calls nextRound()

    Locked --> InSettlement: Round N → InSettlement
    InSettlement --> Settled: Keeper calls setRoundSettled(N)

    Settled --> Exchangeable: User calls redeemExchangeAsset()\ngets exchange asset
    Exchangeable --> [*]: Receipt burned
    Redeemable --> [*]: Receipt burned
```

**Key rules:**

  * `redeem(id, amount, receiver, owner)` — burns receipt, returns the **deposit token** (same asset deposited). Only works for `id == currentRound`.
  * `redeemExchangeAsset(id, amount, receiver, owner)` — burns receipt, returns the **exchange asset** at the snapshotted exchange rate. Only works for `id < currentRound` AND `roundState[id] == Settled`.

-----

## 4\. Round State Machine (Two-Phase Settlement)

To protect the protocol from "Penny-Grief" Denial of Service attacks and to correctly absorb T+1 off-chain NAV updates, rounds are processed in two distinct phases:

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Opened: Round created
    Opened --> InSettlement: Keeper calls nextRound()
    InSettlement --> Settled: Keeper calls setRoundSettled(N)
```

| State | Enum value | Deposits | Redeem (current) | Exchange (past) |
|-------|-----------|----------|-------------------|-----------------|
| `Opened` | 0 → active | ✅ Yes | ✅ Yes | ❌ No |
| `InSettlement` | 1 | ❌ No (new round opened) | ❌ No | ❌ No |
| `Settled` | 2 | ❌ No | ❌ No | ✅ Yes |

### Phase 1: `nextRound()`

Closes the round and freezes its liabilities.

1.  Sets current round `N` to `InSettlement`.
2.  Increments round to `N+1` and sets it to `Opened`.

### Phase 2: `setRoundSettled(roundId)`

Executes the physical trade and snapshots the real-world execution rate.

1.  Retrieves the exact locked liability (`frozenAmount = totalSupply(roundId)`).
2.  Executes `_operate(roundId, frozenAmount)`.
3.  Records the actual `outputAmount` received from the target vault.
4.  Snapshots the exchange rate via `toPrice(outputAmount, frozenAmount)`.
5.  Sets round `N` to `Settled`.

-----

## 5\. Input Vault (Deposit Flow)

| Property | Value |
|----------|-------|
| Contract | [RoundsVaultInput.sol](./RoundsVaultInput.sol) |
| `asset()` | Underlying token (e.g. USDC) |
| `exchangeAsset()` | FleetCommander address (= Fleet shares) |
| `vault()` | FleetCommander address |

### Deposit → Exchange flow

```mermaid
sequenceDiagram
    participant User
    participant InputVault as RoundsVaultInput
    participant Fleet as FleetCommander
    participant Ark as T+1 Ark

    Note over User,Ark: Phase 1: Deposit
    User->>InputVault: deposit(1000 USDC, user)
    InputVault->>InputVault: mint ERC1155<br/>id=currentRound, amount=1000e6

    Note over User,Ark: Phase 2: Advance (Lock)
    InputVault->>InputVault: nextRound() [Keeper]

    Note over User,Ark: Phase 3: Off-chain settlement & Rebalance
    Fleet->>Ark: board(USDC) via rebalance
    Ark->>Ark: USDC sent to offchain RWA
    Note right of Ark: T+0/T+1 settlement

    Note over User,Ark: Phase 4: Execute & Settle
    rect rgb(255, 245, 230)
        InputVault->>InputVault: setRoundSettled(N) [Keeper]
        InputVault->>Fleet: deposit(frozenAmount)
        Fleet->>Fleet: mint Fleet shares to InputVault
        InputVault->>InputVault: snapshot exact execution rate
    end

    Note over User,Ark: Phase 5: Exchange
    User->>InputVault: redeemExchangeAsset(N)
    InputVault->>InputVault: burn ERC1155
    InputVault->>User: transfer Fleet shares
```

### `_operate()` implementation

```solidity
function _operate(uint256 roundId, uint256 amount) internal override returns (uint256) {
    if (amount == 0) return 0;
    uint256 shares = _depositOnTarget(amount);
    emit AssetsDeposited(roundId, _msgSender(), amount, shares);
    return shares;
}
```

-----

## 6\. Output Vault (Withdrawal Flow)

| Property | Value |
|----------|-------|
| Contract | [RoundsVaultOutput.sol](./RoundsVaultOutput.sol) |
| `asset()` | FleetCommander (= Fleet shares) |
| `exchangeAsset()` | Underlying token (e.g. USDC) |
| `vault()` | FleetCommander address |

### Withdrawal → Exchange flow

```mermaid
sequenceDiagram
    participant User
    participant OutputVault as RoundsVaultOutput
    participant Fleet as FleetCommander

    Note over User,Fleet: Phase 1: Deposit Fleet shares
    User->>OutputVault: deposit(500 shares, user)
    OutputVault->>OutputVault: mint ERC1155

    Note over User,Fleet: Phase 2: Advance (Lock)
    OutputVault->>OutputVault: nextRound() [Keeper]

    Note over User,Fleet: Phase 3: Request & Off-chain settlement
    Fleet->>Fleet: Keeper requests off-chain withdrawal
    Note right of Fleet: T+0/T+1 settlement... USDC sweeps to Buffer

    Note over User,Fleet: Phase 4: Execute & Settle
    rect rgb(230, 245, 255)
        OutputVault->>OutputVault: setRoundSettled(N) [Keeper]
        OutputVault->>Fleet: redeem(frozenAmount)
        Fleet->>OutputVault: transfer exact USDC yield/loss
        OutputVault->>OutputVault: snapshot exact execution rate
    end

    Note over User,Fleet: Phase 5: Exchange
    User->>OutputVault: redeemExchangeAsset(N)
    OutputVault->>User: transfer exactly pro-rata USDC
```

### `_operate()` implementation (Output)

```solidity
function _operate(uint256 roundId, uint256 amount) internal override returns (uint256) {
    if (amount == 0) return 0;
    uint256 assets = _redeemFromTarget(amount);
    emit SharesRedeemed(roundId, _msgSender(), amount, assets);
    return assets;
}
```

-----

## 7\. Exchange Rate Math

The `Price` struct from `@summerfi/price-solidity`:

```solidity
struct Price {
    uint256 baseAmount;    // numerator
    uint256 quoteAmount;   // denominator
}
```

**Quoting**: `price.quote(amount)` returns `amount * baseAmount / quoteAmount`

Because `setRoundSettled()` generates the rate using actual output received (`toPrice(outputAmount, frozenAmount)`), the math organically perfectly absorbs off-chain slippage, NAV changes, or withdrawal fees.

### Input Vault rate interpretation

| Field | Meaning |
|-------|---------|
| `baseAmount` | Exact Fleet shares received from the FleetCommander trade |
| `quoteAmount` | Exact frozen USDC deposited by users in this round |
| `quote(receiptAmount)` | Users get exact pro-rata share of the executed trade |

### Output Vault rate interpretation

| Field | Meaning |
|-------|---------|
| `baseAmount` | Exact USDC received from the FleetCommander trade |
| `quoteAmount` | Exact frozen Fleet shares deposited by users in this round |
| `quote(receiptAmount)` | Users get exact pro-rata share of the returned USDC |

-----

## 8. T+1 Ark Internals {#8-t1-ark-internals}

The [T+1 Ark (WisdomTreeArk.sol)](../arks/WisdomTreeArk.sol) handles the on-chain/off-chain bridge to offchain RWA funds.

### NAV Calculation (`totalAssets`)

```
totalAssets = sharesToAssets(currentShares) + pendingDepositAssets + pendingWithdrawalAssets
```

Where `currentShares` uses either cached or live balance:

```solidity
uint256 currentShares = pendingDepositAssets > 0
    ? cachedShareBalance              // frozen during pending deposit
    : shareToken.balanceOf(forwarder); // live balance
```

### Oracle Price Conversion

Uses Chainlink `AggregatorV3Interface`:

```
sharesToAssets(shares) = price.invert().quote(shares)
// where price = { base: 1 share, quote: oraclePrice in asset decimals }
```

### Deposit Lifecycle

```mermaid
stateDiagram-v2
    direction TB
    [*] --> Idle
    Idle --> PendingDeposit: board() called by FleetCommander
    note right of PendingDeposit
        cachedShareBalance = snapshot
        pendingDepositAssets += amount
        USDC forwarded to custodianWallet
    end note
    PendingDeposit --> PendingDeposit: More board() calls [MoneyMarket only]
    PendingDeposit --> Idle: Keeper clearPendingDeposit()
    note right of Idle
        pendingDepositAssets = 0
        totalAssets uses live balance
        (includes new WT shares)
    end note
```

### Withdrawal Lifecycle

```mermaid
stateDiagram-v2
    direction TB
    [*] --> Idle
    Idle --> PendingWithdrawal: requestWithdrawal(amount)
    note right of PendingWithdrawal
        shares sent to custodianWallet
        pendingWithdrawalAssets += amount
        pendingWithdrawalShares += shares
    end note
    PendingWithdrawal --> Idle: sweep()
    note right of Idle
        USDC swept from forwarder → buffer
        pendingWithdrawalAssets = 0
        pendingWithdrawalShares = 0
    end note
```

### Price Freeze Mechanism

For non-MMF funds (e.g. CRDYX), dividends cause a NAV dip at ex-dividend date. The Keeper can freeze the Ark:

```solidity
setArkFrozen(true, type(uint256).max)  // freezes at current totalAssets
// ... dividend period passes, shares arrive ...
setArkFrozen(false, 0)                 // unfreezes, new shares recognized
```

When frozen, `totalAssets()` returns the stored `_frozenTotalAssets` regardless of oracle or share balance changes.

-----

## 9\. Keeper Operations Playbook

### Deposit Round Lifecycle

| Step | Action | Contract | Function |
|------|--------|----------|----------|
| 1 | Users deposit during open round | RoundsVaultInput | `deposit(assets, receiver)` |
| 2 | Advance round (freezes amount) | RoundsVaultInput | `nextRound()` |
| 3 | Rebalance USDC into Ark | FleetCommander | `rebalance([{buffer→ark}])` |
| 4 | Wait for WT settlement (T+0/T+1) | — | — |
| 5 | Clear pending deposit (NAV updates)| T+1 Ark | `clearPendingDeposit()` |
| 6 | Execute trade & settle round | RoundsVaultInput | `setRoundSettled(N)` |

### Withdrawal Round Lifecycle

| Step | Action | Contract | Function |
|------|--------|----------|----------|
| 1 | Users deposit Fleet shares | RoundsVaultOutput | `deposit(shares, receiver)` |
| 2 | Advance round (freezes amount) | RoundsVaultOutput | `nextRound()` |
| 3 | Request withdrawal from Ark | T+1 Ark | `requestWithdrawal(amount)` |
| 4 | Wait for WT USDC return (T+0/T+1) | — | — |
| 5 | Sweep returning USDC to buffer | T+1 Ark | `sweep()` |
| 6 | Execute trade & settle round | RoundsVaultOutput | `setRoundSettled(N)` |

### Dividend Handling (Non-MMF)

| Step | Action | Function |
|------|--------|----------|
| 1 | Ex-dividend declared | `setArkFrozen(true, MAX)` |
| 2 | Dividend shares arrive | — |
| 3 | Unfreeze | `setArkFrozen(false, 0)` |

---

## 10\. Entry Point Analysis

### Summary

| Access Level | Count | Priority |
|-------------:|------:|----------|
| Public (Whitelisted) | 11 | 🔴 High |
| Keeper-restricted | 14 | 🟠 Medium |
| Admin / Governor | 10 | 🟡 Low |

### Public (Whitelisted) Entry Points

| Function | Contract | Restrictions | What it does |
|----------|----------|-------------|-------------|
| `deposit(assets, receiver)` | RoundsVaultBase | `onlyWhitelisted` | Deposits asset, mints ERC-1155 receipt for current round |
| `redeem(id, amount, ...)` | RoundsVaultBase | `onlyWhitelisted` + `currentRound` | Burns current-round receipt, returns deposit token |
| `redeemExchangeAsset(...)` | RoundsVaultBase | `onlyWhitelisted` + `Settled` | Burns past receipt, returns exchange asset at snapshotted rate |
| `deposit / mint` | FleetCommander | `_enforceEntryGateway` | Direct entry to Fleet if Gateway is OPEN |
| `withdraw / redeem` | FleetCommander | `_enforceExitGateway` | Direct exit from Fleet if Gateway is OPEN |
| `withdrawFromBuffer / Arks` | FleetCommander | `_enforceExitGateway` | Specialized exit functions for Fleet |

### Keeper-Restricted Entry Points

| Function | Contract | What it does |
|----------|----------|-------------|
| `nextRound()` | RoundsVaultBase | Closes round, freezes liability, opens next round |
| `setRoundSettled(roundId)` | RoundsVaultBase | Executes physical trade, snapshots rate, sets to Settled |
| `rebalance(rebalanceData)` | FleetCommander | Moves assets between Arks and adjusts buffer |
| `clearPendingDeposit()` | T+1 Ark | Clears full/partial pending deposit, updates NAV |
| `requestWithdrawal(amount)` | T+1 Ark | Initiates off-chain redemption flow |
| `sweep()` | T+1 Ark | Refills buffer with returned off-chain funds |
| `setArkFrozen(bool, NAV)` | T+1 Ark | Freezes/unfreezes NAV reporting during settlement |
| `setCustodianWallet(...)` | T+1 Ark | Updates the target for off-chain transfers |
| `setAssetsForwarder(...)` | T+1 Ark | Updates the secure transfer proxy |

### Admin / Governor-Restricted Entry Points

| Function | Contract | Role Required | What it does |
|----------|----------|-------------|-------------|
| `setWhitelisted(acc, bool)` | PAMV2 | `WHITELIST_MANAGER` | Updates global whitelist status |
| `setWhitelistedBatch(...)` | PAMV2 | `WHITELIST_MANAGER` | Batch updates global whitelist |
| `grantOperatorRole(...)` | PAMV2 | `GOVERNOR_ROLE` | Authorizes an vault/contract as an Operator |
| `setOperatorGatewayStatus` | FleetCommander | `GOVERNOR_ROLE` | Toggles direct user access to Fleet |
| `setTipRate(Percentage)` | FleetCommander | `GOVERNOR_ROLE` | Updates protocol fee rate |
| `pause / unpause` | FleetCommander | `GOVERNOR_ROLE` | Emergency circuit breaker |
| `emergencySweep()` | T+1 Ark | `GOVERNOR_ROLE` | Force-sweep funds bypassing slippage checks |

-----

## 11\. Systemic Risks and Operational Limitations

#### 1\. The Output Vault "Round Block" (Resolved via Two-Phase)

*Previously, advancing a round demanded immediate synchronous USDC, risking reverts if the Fleet buffer was empty.*

  * **Resolution**: By splitting the cycle into `nextRound()` and `setRoundSettled()`, the liquidity deadlock is solved. The Keeper can advance the round (locking the liabilities), initiate the off-chain `requestWithdrawal` to offchain RWA, wait for the USDC to hit the buffer via `sweep()`, and *only then* execute `setRoundSettled()`.

#### 2\. Resolved: Systemic Whitelist Fragmentation

  * **Current Architecture**: The protocol uses a centralized `ProtocolAccessManagerV2`. The `Whitelist.sol` utility is a stateless proxy. If a user is approved in the RoundsVault, they are cryptographically guaranteed to be approved in the FleetCommander, eliminating fragmentation.

#### 3\. Oracle Update & NAV Lag (Perfectly Absorbed)

Because `setRoundSettled()` snapshots the exchange rate using the literal `outputAmount` received from the trade rather than a predictive oracle query, the RoundsVault is immune to systemic insolvency. If the off-chain NAV drops overnight, the `setRoundSettled()` calculation inherently passes that loss pro-rata to the users of that specific round, maintaining perfect 1:1 asset backing in the smart contract.