# Rounds Vault & Institutional Ark — Technical Reference

> Complete technical documentation for the async settlement architecture used by WisdomTree (and future Benji-token-style) integrations.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Contract Hierarchy](#2-contract-hierarchy)
3. [Token Model: Receipts (ERC-1155 NFTs)](#3-token-model-receipts-erc-1155-nfts)
4. [Round State Machine](#4-round-state-machine)
5. [Input Vault (Deposit Flow)](#5-input-vault-deposit-flow)
6. [Output Vault (Withdrawal Flow)](#6-output-vault-withdrawal-flow)
7. [Exchange Rate Math](#7-exchange-rate-math)
8. [WisdomTreeArk Internals](#8-wisdomtreeark-internals)
9. [Keeper Operations Playbook](#9-keeper-operations-playbook)
10. [Entry Point Analysis](#10-entry-point-analysis)
11. [Systemic Risks & Operational Limitations](#11-systemic-risks-and-operational-limitations)

---

## 1. Architecture Overview

The Rounds Vault system solves a fundamental problem: institutional tokenized funds (e.g. WisdomTree WTGXX, CRDYX, and future Benji tokens) have **locked investment periods** where deposits/withdrawals are processed in T+0 or T+1 off-chain settlement cycles. Users cannot interact directly during these periods.

The Rounds Vault acts as an **asynchronous buffering layer** between users and the FleetCommander ERC-4626 vault.

```mermaid
flowchart LR
    U[User] -->|deposit USDC| IV[RoundsVaultInput]
    IV -->|"nextRound()"| FC[FleetCommander]
    FC -->|"board()"| ARK[WisdomTreeArk]
    ARK -->|USDC wire| WT[WisdomTree\nOff-Chain]
    WT -->|shares| ARK
    ARK -.->|totalAssets ↑| FC
    FC -.->|previewDeposit| IV
    IV -->|exchange receipts| U2[User receives\nFleet shares]

    U3[User] -->|deposit Fleet shares| OV[RoundsVaultOutput]
    OV -->|"nextRound()"| FC2[FleetCommander]
    FC2 -->|"disembark()"| ARK2[WisdomTreeArk]
    ARK2 -->|shares wire| WT2[WisdomTree\nOff-Chain]
    WT2 -->|USDC| ARK2
    ARK2 -.->|sweep → buffer| FC2
    OV -->|exchange receipts| U4[User receives USDC]
```

---

## 2. Contract Hierarchy

```mermaid
classDiagram
    class ERC4626MultiToken {
        +deposit(assets, receiver) uint256
        +redeem(id, amount, receiver, owner) uint256
        +balanceOf(account, id) uint256
        #_getMintId() uint256
    }

    class ERC4626MultiTokenWrapper {
        -_proxiedVault : IERC4626
        +vault() address
        #_depositOnTarget(amount) uint256
        #_redeemFromTarget(amount) uint256
    }

    class RoundsVaultBase {
        -_roundNumber : uint256
        -_exchangeRateByRound : mapping
        -_exchangeAsset : address
        +nextRound() [Keeper]
        +setRoundSettled(roundNumber) [Keeper]
        +deposit(assets, receiver) [Whitelisted]
        +redeem(id, amount, receiver, owner) [Whitelisted]
        +redeemExchangeAsset(id, amount, receiver, owner) [Whitelisted]
        #_operate() virtual
        #_getCurrentExchangeRate() virtual
    }

    class RoundsVaultInput {
        #_operate() : deposits USDC → Fleet
        #_getCurrentExchangeRate() : previewDeposit(1)
    }

    class RoundsVaultOutput {
        #_operate() : redeems Fleet shares → USDC
        #_getCurrentExchangeRate() : previewRedeem(1)
    }

    ERC4626MultiToken <|-- ERC4626MultiTokenWrapper
    ERC4626MultiTokenWrapper <|-- RoundsVaultBase
    RoundsVaultBase <|-- RoundsVaultInput
    RoundsVaultBase <|-- RoundsVaultOutput
```

---

## 3. Token Model: Receipts (ERC-1155 NFTs)

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
- `redeem(id, amount, receiver, owner)` — burns receipt, returns the **deposit token** (same asset deposited). Only works for `id == currentRound`.
- `redeemExchangeAsset(id, amount, receiver, owner)` — burns receipt, returns the **exchange asset** at the snapshotted exchange rate. Only works for `id < currentRound` AND `roundState[id] == Settled`.

---

## 4. Round State Machine

Each round has a state tracked in `roundState[roundNumber]`:

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Opened: Round created
    Opened --> InSettlement: Keeper calls nextRound()
    InSettlement --> Settled: Keeper calls setRoundSettled()
```

| State | Enum value | Deposits | Redeem (current) | Exchange (past) |
|-------|-----------|----------|-------------------|-----------------|
| `Opened` | 0 → active | ✅ Yes | ✅ Yes | ❌ No |
| `InSettlement` | 1 | ❌ No (new round opened) | ❌ No | ❌ No |
| `Settled` | 2 | ❌ No | ❌ No | ✅ Yes |

### `nextRound()` does 4 things atomically:

1. **Snapshots the exchange rate** → `_exchangeRateByRound[N] = _getCurrentExchangeRate()`
2. **Sets round N to InSettlement** → `roundState[N] = InSettlement`
3. **Executes `_operate()`** → deposits/redeems bulk into/from the FleetCommander
4. **Increments round** → `_roundNumber++`, sets new round to `Opened`

---

## 5. Input Vault (Deposit Flow)

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
    participant Ark as WisdomTreeArk

    Note over User,Ark: Phase 1: Deposit
    User->>InputVault: deposit(1000 USDC, user)
    InputVault->>InputVault: mint ERC1155<br/>id=currentRound, amount=1000e6

    Note over User,Ark: Phase 2: Settlement (Keeper)
    rect rgb(255, 245, 230)
        InputVault->>InputVault: nextRound() [Keeper only]
        InputVault->>InputVault: snap rate = previewDeposit(1e6)
        InputVault->>Fleet: deposit(totalAssets, self)
        Fleet->>Fleet: mint Fleet shares to InputVault
        Fleet->>Ark: board(USDC) via rebalance
    end

    Note over User,Ark: Phase 3: Off-chain settlement
    Ark->>Ark: USDC sent to WisdomTree
    Note right of Ark: T+0/T+1 settlement

    Note over User,Ark: Phase 4: Exchange
    User->>InputVault: redeemExchangeAsset(roundId, amount, user, user)
    InputVault->>InputVault: burn ERC1155
    InputVault->>InputVault: exchangeAmount = rate.quote(amount)
    InputVault->>User: transfer Fleet shares
```

### `_operate()` implementation

```solidity
function _operate() internal override {
    uint256 assets = totalAssets();       // all USDC sitting in the vault
    if (assets > 0) {
        uint256 shares = _depositOnTarget(assets);  // Fleet.deposit(assets, self)
    }
}
```

### `_getCurrentExchangeRate()` (Input)

```solidity
function _getCurrentExchangeRate() internal view override returns (Price memory) {
    uint256 OneAsset = 10 ** asset_.decimals();   // e.g. 1e6 for USDC
    uint256 shares = IERC4626(vault()).previewDeposit(OneAsset);
    return toPrice(shares, OneAsset);
    // Price = { baseAmount: shares, quoteAmount: OneAsset }
    // quote(receiptAmount) = receiptAmount * shares / OneAsset
}
```

> ⚠️ **Issue**: This rate is polled at `1e6` scale, not from the actual bulk deposit result. See [audit report](./rounds_vault_audit.md) Finding #1.

---

## 6. Output Vault (Withdrawal Flow)

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
    OutputVault->>OutputVault: mint ERC1155<br/>id=currentRound, amount=500

    Note over User,Fleet: Phase 2: Settlement (Keeper)
    rect rgb(230, 245, 255)
        OutputVault->>OutputVault: nextRound() [Keeper only]
        OutputVault->>OutputVault: snap rate = previewRedeem(1 share)
        OutputVault->>Fleet: redeem(totalAssets, self, self)
        Fleet->>OutputVault: transfer USDC
    end

    Note over User,Fleet: Phase 3: Exchange
    User->>OutputVault: redeemExchangeAsset(roundId, amount, user, user)
    OutputVault->>OutputVault: burn ERC1155
    OutputVault->>User: transfer USDC
```

### `_operate()` implementation (Output)

```solidity
function _operate() internal override {
    uint256 shares = totalAssets();       // all Fleet shares in the vault
    if (shares > 0) {
        uint256 assets = _redeemFromTarget(shares);  // Fleet.redeem(shares, self, self)
    }
}
```

### `_getCurrentExchangeRate()` (Output)

```solidity
function _getCurrentExchangeRate() internal view override returns (Price memory) {
    uint256 OneAsset = 10 ** asset_.decimals();   // 1 full Fleet share
    uint256 assets = IERC4626(vault()).previewRedeem(OneAsset);
    return toPrice(assets, OneAsset);
    // quote(receiptAmount) = receiptAmount * assets / OneAsset
}
```

---

## 7. Exchange Rate Math

The `Price` struct from `@summerfi/price-solidity`:

```solidity
struct Price {
    uint256 baseAmount;    // numerator
    uint256 quoteAmount;   // denominator
}
```

**Quoting**: `price.quote(amount)` returns `amount * baseAmount / quoteAmount`

### Input Vault rate interpretation

| Field | Meaning |
|-------|---------|
| `baseAmount` | Fleet shares received for 1 full underlying token |
| `quoteAmount` | 1 full underlying token (`10 ** decimals`) |
| `quote(receiptAmount)` | How many Fleet shares the user gets for `receiptAmount` receipts |

### Output Vault rate interpretation

| Field | Meaning |
|-------|---------|
| `baseAmount` | USDC received for 1 full Fleet share |
| `quoteAmount` | 1 full Fleet share (`10 ** decimals`) |
| `quote(receiptAmount)` | How much USDC the user gets for `receiptAmount` receipts |

---

## 8. WisdomTreeArk Internals

[WisdomTreeArk.sol](../arks/WisdomTreeArk.sol) handles the on-chain/off-chain bridge to WisdomTree funds.

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

---

## 9. Keeper Operations Playbook

### Deposit Round Lifecycle

| Step | Action | Contract | Function |
|------|--------|----------|----------|
| 1 | Users deposit during open round | RoundsVaultInput | `deposit(assets, receiver)` |
| 2 | Advance round, dispatch USDC | RoundsVaultInput | `nextRound()` |
| 3 | Rebalance USDC into Ark | FleetCommander | `rebalance([{buffer→ark}])` |
| 4 | Wait for WT settlement (T+0/T+1) | — | — |
| 5 | WT sends shares to forwarder | WisdomTree (off-chain) | — |
| 6 | Clear pending deposit | WisdomTreeArk | `clearPendingDeposit()` |
| 7 | Mark round as settled | RoundsVaultInput | `setRoundSettled(N)` |

### Withdrawal Round Lifecycle

| Step | Action | Contract | Function |
|------|--------|----------|----------|
| 1 | Users deposit Fleet shares | RoundsVaultOutput | `deposit(shares, receiver)` |
| 2 | Advance round, redeem from Fleet | RoundsVaultOutput | `nextRound()` |
| 3 | Request withdrawal from Ark | WisdomTreeArk | `requestWithdrawal(amount)` |
| 4 | Wait for WT USDC return (T+0/T+1) | — | — |
| 5 | USDC arrives in forwarder | WisdomTree (off-chain) | — |
| 6 | Sweep USDC to buffer | WisdomTreeArk | `sweep()` |
| 7 | Mark round as settled | RoundsVaultOutput | `setRoundSettled(N)` |

### Dividend Handling (Non-MMF)

| Step | Action | Function |
|------|--------|----------|
| 1 | Ex-dividend declared | `setArkFrozen(true, MAX)` |
| 2 | Dividend shares arrive | — |
| 3 | Unfreeze | `setArkFrozen(false, 0)` |

---

## 10. Entry Point Analysis

### Summary

| Access Level | Count | Priority |
|-------------:|------:|----------|
| Public (Whitelisted) | 6 | 🔴 High |
| Keeper-restricted | 12 | 🟠 Medium |
| Governor-restricted | 4 | 🟡 Low |
| View/Pure | 8 | ⚪ Info |

### Public (Whitelisted) Entry Points

| Function | Contract | Restrictions | What it does |
|----------|----------|-------------|-------------|
| `deposit(assets, receiver)` | RoundsVaultBase | `onlyWhitelisted(sender, receiver)` | Deposits asset, mints ERC-1155 receipt for current round |
| `redeem(id, amount, receiver, owner)` | RoundsVaultBase | `onlyWhitelisted` + `id == currentRound` | Burns current-round receipt, returns deposit token |
| `redeemBatch(ids, amounts, receiver, owner)` | RoundsVaultBase | `onlyWhitelisted` + all `ids == currentRound` | Batch redeem for current round only |
| `redeemExchangeAsset(id, amount, receiver, owner)` | RoundsVaultBase | `onlyWhitelisted` + `id < currentRound` + `Settled` | Burns past receipt, returns exchange asset at snapshotted rate |
| `redeemExchangeAssetBatch(ids, amounts, receiver, owner)` | RoundsVaultBase | Same as above, batch | Batch exchange across multiple settled rounds |
| `setWhitelisted(account, allowed)` | Whitelist | `onlyGovernor` | Manages whitelist |

### Keeper-Restricted Entry Points

| Function | Contract | What it does |
|----------|----------|-------------|
| `nextRound()` | RoundsVaultBase | Snapshots rate, executes settlement, advances round |
| `setRoundSettled(roundNumber)` | RoundsVaultBase | Marks a round as settled for exchange |
| `setRoundSettledBatch(roundNumbers)` | RoundsVaultBase | Batch settle multiple rounds |
| `clearPendingDeposit()` | WisdomTreeArk | Clears full pending deposit, unfreezes share cache |
| `clearPendingDeposit(amount)` | WisdomTreeArk | Partial pending deposit clear |
| `requestWithdrawal(amount)` | WisdomTreeArk | Sends shares to custodian, records pending withdrawal |
| `sweep()` | WisdomTreeArk | Sweeps returned USDC to buffer, clears pending withdrawal |
| `setArkFrozen(bool, uint256)` | WisdomTreeArk | Freezes/unfreezes NAV reporting |
| `setCustodianWallet(address)` | WisdomTreeArk | Updates the off-chain wallet address |
| `setAssetsForwarder(address)` | WisdomTreeArk | Updates the forwarder contract |
| `setSweepSlippage(Percentage)` | WisdomTreeArk | Adjusts slippage tolerance (max 0.5%) |
| `claimWithdrawal()` | WisdomTreeArk | No-op (off-chain settlement) |

### Governor-Restricted Entry Points

| Function | Contract | What it does |
|----------|----------|-------------|
| `setWhitelisted(account, allowed)` | RoundsVaultBase | Add/remove from vault whitelist |
| `setWhitelistedBatch(accounts, allowed)` | RoundsVaultBase | Batch whitelist management |
| `setWhitelisted(account, allowed)` | FleetCommanderWhitelist | Add/remove from Fleet whitelist |
| `setWhitelistedBatch(accounts, allowed)` | FleetCommanderWhitelist | Batch Fleet whitelist management |


## 11. Systemic Risks and Operational Limitations

#### 1. The Output Vault "Round Block" (Liquidity Deadlock)
`RoundsVaultOutput.nextRound()` demands immediate, synchronous USDC from the FleetCommander. Because `WisdomTreeArk` returns `0` for `_withdrawableTotalAssets()`, the FleetCommander *cannot* withdraw from it synchronously.
- **Limitation**: If the `bufferArk` (and other liquid arks) do not have enough loose USDC to cover the total redemptions for the round, **`nextRound()` will REVERT**.
- **Impact**: This breaks the deterministic length of Rounds. The round is stuck in `InSettlement` until the Keeper manually triggers a `requestWithdrawal` on WisdomTreeArk, waits for the T+1/T+2 off-chain wire to clear, and calls `sweep()` to refill the buffer.

#### 2. Systemic Whitelist Fragmentation
The Input vault accepts vanilla USDC (no whitelist) but distributes `FleetCommander` shares (strictly whitelisted). 
- **The Trap**: If a user is whitelisted in `RoundsVault` but NOT in the `FleetCommander`, their deposit succeeds. However, when they attempt to redeem their exchange asset, the `SafeERC20.transfer` from the vault to the user **reverts permanently**.
- **Mitigation**: Admins must ensure dual-whitelisting at both the Vault and Fleet layers for all users.

#### 3. Oracle Update & NAV Lag
When the Keeper rebalances USDC from the `bufferArk` to `WisdomTreeArk`, `pendingDepositAssets > 0`.
- **The Drag Effect**: During the off-chain transfer window, those assets are valued strictly at 1:1. They do not benefit from any share price appreciation recorded by the Oracle. If it takes 2 days to clear, users experience 2 days of "yield drag" on new deposits.
- **The Sandwich Risk**: When `clearPendingDeposit()` is called, the Ark realizes the new shares. If the oracle updates to a higher price *right before* `clearPendingDeposit` is called, the protocol NAV jumps abruptly rather than smoothly.

### Applicability to Benji-style Arks

Any future Ark that follows the same pattern (cached share balance + pending deposit/withdrawal + off-chain settlement) will inherit the same architecture and the same risk profile. The documentation and keeper playbook above apply identically — only the off-chain counterparty and settlement timing differ.
