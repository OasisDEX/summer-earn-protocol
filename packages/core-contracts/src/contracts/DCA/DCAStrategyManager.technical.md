# DCAStrategyManager — Technical & Integration Reference

> **Audience:** smart-contract integrators (frontend, keeper, subgraph) **and**
> security reviewers / auditors.
> **Scope:** `DCAStrategyManager.sol` and its direct dependencies
> (`EnsoRouterSwapper`, `Permit2Consumer`, `HarborCommandConsumer`,
> `ChainlinkOracleUtils`) plus the `IDCAStrategyManager` interface/events/errors.
> **Companion docs:** [`DCAStrategyManager.product.md`](./DCAStrategyManager.product.md)
> (non-technical), [`CLAUDE.md`](./CLAUDE.md) (maintainer invariants),
> [`DCAStrategyManager.ai-audit.md`](./DCAStrategyManager.ai-audit.md)
> (AI adversarial audit — fresh findings; see §15).
>
> Line references are against the source at the time of writing; re-verify
> against the contract before relying on any single number.

---

## 1. At a glance

| Property | Value |
|----------|-------|
| Solidity | `0.8.28` |
| License | BUSL-1.1 |
| Funds custody | **None held between transactions** (atomic pull→swap→deliver) |
| Reentrancy | `ReentrancyGuardTransient` (transient-storage guard) on every state-changing external fn |
| Ownership model | Stateless commitment: `keccak256(abi.encode(config))` + `msg.sender == config.owner` |
| Trade unit | **Source-vault shares** (`tradeAmount`) |
| Swap venue | Enso router (keeper-supplied calldata) |
| Pricing | Two Chainlink USD feeds → cross-rate; slippage floor in BPS |
| Allowances | Permit2 `AllowanceTransfer` (recurring pulls) + `SignatureTransfer` (one-shot deposit) |

**Inheritance:**
`IDCAStrategyManager`, `IDCAStrategyManagerErrors`, `IDCAStrategyManagerEvents`,
`ReentrancyGuardTransient`, `ProtocolAccessManaged`, `Permit2Consumer`,
`EnsoRouterSwapper`, `HarborCommandConsumer`.

**Constructor** (`DCAStrategyManager.sol:91`):

```solidity
constructor(
    address _accessManager,  // ProtocolAccessManager — governs keeper roles
    address _ensoRouter,     // Enso aggregator router (all swaps)
    address _harborCommand,  // HarborCommand registry (FleetCommander validation)
    address _permit2         // Uniswap Permit2 singleton
)
```

All four addresses are validated non-zero by their respective base constructors.

**Constants** (`DCAStrategyManager.sol:56-62`):

| Constant | Value | Meaning |
|----------|-------|---------|
| `_MIN_INTERVAL` | `1 days` | Minimum seconds between executions |
| `_MAX_INTERVAL` | `90 days` | Maximum interval |
| `_MAX_SLIPPAGE_BPS` | `5000` BPS (50%) | Maximum allowed slippage |
| `MAX_ORACLE_STALENESS` | `86400` s (24h) | (in `ChainlinkOracleUtils`) **default** max Chainlink round age, used when a feed's `maxStaleness == 0`; set a tighter per-feed value in `StrategyConfig.{in,out}AssetFeed.maxStaleness` |

---

## 2. Architecture & dependencies

```
                 ┌─────────────────────────────────────────────┐
   owner ───────▶│              DCAStrategyManager              │
   (EOA / app)   │  - createStrategy / depositAndCreate / *WithPermit2
                 │  - editStrategy / pause / resume / cancel    │
   keeper ──────▶│  - executeStrategy (onlyKeeper)              │
   (bot)         │  - checkUpkeep / strategyStates (views)      │
                 └───┬──────────┬───────────┬──────────┬────────┘
                     │          │           │          │
       Permit2Consumer   EnsoRouterSwapper  Harbor    ProtocolAccessManaged
       (pull shares)     (approve→call→     Command   (keeper roles)
                          reset)            Consumer
                     │          │           │
            Uniswap Permit2   Enso router   HarborCommand registry
                                            │
                                   ChainlinkOracleUtils (library)
                                            │
                                   Chainlink AggregatorV3 feeds
```

- **`Permit2Consumer`** — `_pullFunds` (AllowanceTransfer), `_applyPermit2Allowance`
  (set sub-allowance from signature), `_pullFundsWithPermit2` (SignatureTransfer).
  Amounts are capped at `uint160` (`AmountOverflowsUint160`).
- **`EnsoRouterSwapper`** — `_ensoSwap(tokenIn, amountIn, data)`: `forceApprove` →
  low-level `call(data)` → `forceApprove(0)`. Reverts `EmptySwapData` / `SwapFailed`.
  **Allowance is reset to 0 unconditionally**, even on router underspend.
- **`HarborCommandConsumer`** — `onlyActiveFleetCommander(vault, label)` reverts
  `InactiveFleetCommander` unless `HARBOR_COMMAND.activeFleetCommanders(vault)`.
- **`ChainlinkOracleUtils`** — `_getPrice(ChainlinkFeed)` (positive + per-feed staleness, default 24h),
  `convertAmount` (in→out via two USD feeds), `crossRate` (1e18-scaled out/in price).

---

## 3. Access control & roles

| Function group | Gate |
|----------------|------|
| `createStrategy*`, `depositAndCreate*` | `ownerOnlySender(config)` → `msg.sender == config.owner` (else `UnauthorizedOwner`) |
| `editStrategy`, `pause`, `resume`, `cancel` | `onlyStrategyOwner(strategyId, config)` → commitment match **and** `msg.sender == config.owner` (else `CommitmentMismatch` / `UnauthorizedAccess`) |
| `executeStrategy` | `onlyKeeper` → caller holds contract-specific `KEEPER_ROLE` **or** global `SUPER_KEEPER_ROLE` (else `CallerIsNotKeeper`) |
| All create/edit/execute | also `onlyActiveFleetCommander` on **both** source and target vaults |
| Views (`checkUpkeep`, `strategyStates`, `strategyCommitments`, `activeCommitments`) | none |

**Keeper check** (`ProtocolAccessManaged._revertIfNotKeeper`):
```solidity
hasRole(generateRole(KEEPER_ROLE, address(this)), sender) || hasRole(SUPER_KEEPER_ROLE, sender)
```

---

## 4. Data model

### `Status` (enum)
`ACTIVE (0)`, `PAUSED (1)`, `COMPLETED (2)`, `CANCELLED (3)`. COMPLETED and
CANCELLED are terminal.

### `StrategyConfig` (hashed into the commitment — field order is wire-critical)

| # | Field | Type | Notes |
|---|-------|------|-------|
| 1 | `owner` | `address` | Controls + receives proceeds. Non-zero. Immutable across edits. |
| 2 | `sourceVault` | `IFleetCommander` | Active FleetCommander; ≠ target. |
| 3 | `targetVault` | `IFleetCommander` | Active FleetCommander; ≠ source. |
| 4 | `inAsset` | `IERC20` | Must == `sourceVault.asset()`. ≠ `outAsset`. |
| 5 | `outAsset` | `IERC20` | Must == `targetVault.asset()`. ≠ `inAsset`. |
| 6 | `inAssetFeed` | `address` | Chainlink feed for `inAsset`. Non-zero. |
| 7 | `outAssetFeed` | `address` | Chainlink feed for `outAsset`. Non-zero. |
| 8 | `tradeAmount` | `uint256` | **Source-vault shares** per trade. > 0. ≤ `uint160` (Permit2). |
| 9 | `interval` | `uint256` | Seconds. `1 day ≤ interval ≤ 90 days`. |
| 10 | `slippageBps` | `uint256` | BPS, ≤ 5000 (50%). |
| 11 | `maxPrice` | `uint256` | 1e18-scaled out-in price ceiling. 0 = off. |
| 12 | `minPrice` | `uint256` | 1e18-scaled out-in price floor. 0 = off. If both set, `minPrice ≤ maxPrice`. |
| 13 | `endDate` | `uint256` | Unix ts; 0 = no end. |
| 14 | `maxTrades` | `uint256` | ≥ 1 (no "unlimited" sentinel). |

> **`strategyId` is NOT a field** — it is the mapping key and an explicit argument
> to owner/keeper functions. Integrators must mirror this: the wire encoding of
> `StrategyConfig` is exactly these 14 fields, in this order.

### `StrategyState` (mutable runtime state)

| Field | Type | Meaning |
|-------|------|---------|
| `status` | `Status` | Current lifecycle state. |
| `tradesExecuted` | `uint248` | Successful executions so far. |
| `nextTriggerAt` | `uint256` | Earliest ts the next execution may run. |
| `lastScheduledAt` | `uint256` | Ts the last schedule was set (basis for edit re-scheduling). |

### `Permit2DepositBundle` (for `depositAndCreateWithPermit2`)

| Field | Type | Purpose |
|-------|------|---------|
| `inAsset` | `ISignatureTransfer.PermitTransferFrom` | One-shot `inAsset` deposit pull. |
| `inAssetSig` | `bytes` | Signature over `inAsset`. |
| `shares` | `IAllowanceTransfer.PermitSingle` | Recurring keeper sub-allowance on source shares. |
| `sharesSig` | `bytes` | Signature over `shares`. |

### Storage

| Slot | Visibility | Type | Purpose |
|------|-----------|------|---------|
| `_nextStrategyId` | private | `uint256` | Next ID (0-based, monotonic). |
| `strategyCommitments` | **public** | `mapping(uint256 => bytes32)` | id → commitment hash. |
| `_strategyStates` | private | `mapping(uint256 => StrategyState)` | id → state (exposed via `strategyStates(id)`). |
| `activeCommitments` | **public** | `mapping(bytes32 => bool)` | hash → active (duplicate guard). |

---

## 5. The commitment scheme (read this before integrating)

```solidity
commitment = keccak256(abi.encode(config));   // _commitmentHash
```

- **Ownership proof is stateless.** No `owner→strategy` mapping exists. Every
  owner-gated call must resupply the *exact current* `StrategyConfig`. The
  contract recomputes the hash and compares to `strategyCommitments[strategyId]`,
  then checks `msg.sender == config.owner`.
- **Implication for integrators:** the app/keeper/subgraph **must persist the full
  config** and resupply it byte-for-byte. A single differing field →
  `CommitmentMismatch`. The chain stores only the hash, so a lost config must be
  reconstructed from the `StrategyCreated` / `StrategyEdited` events.
- **Duplicate prevention is O(1):** `activeCommitments[hash]` is set on
  create/edit. An identical active config reverts `DuplicateStrategy`.
- **Terminal states do NOT free the hash.** A CANCELLED/COMPLETED config's hash
  stays locked. Re-running "the same" plan requires changing ≥1 field (commonly
  a new `endDate`). `editStrategy` is blocked once terminal (so it cannot be used
  to free a terminal hash).

---

## 6. External API reference

### Create

| Function | Extra inputs | Pre-conditions beyond validation |
|----------|--------------|----------------------------------|
| `createStrategy(config)` → `id` | — | Caller already set up Permit2 sub-allowance for keeper pulls. |
| `depositAndCreate(config, assetAmount, expectedMinShares)` → `id` | `assetAmount > 0` (`ZeroDeposit`); minted shares ≥ `expectedMinShares` (`DepositSharesBelowMin`) | Caller pre-approved `inAsset → manager` (ERC20). Manager deposits to `sourceVault` with **shares → caller**. |
| `createStrategyWithPermit2(config, permitSingle, sig)` → `id` | `permitSingle.details.token == sourceVault` (`InvalidPermit2Token`); spender == manager (`InvalidPermit2Spender`) | Caller pre-approved `sourceVaultShares → Permit2`. Sub-allowance set in-tx. |
| `depositAndCreateWithPermit2(config, assetAmount, permits, expectedMinShares)` → `id` | `assetAmount > 0`; `permits.shares.details.token == sourceVault`; minted shares ≥ `expectedMinShares` (`DepositSharesBelowMin`) | Caller pre-approved both `inAsset → Permit2` and `sourceVaultShares → Permit2`. Two signatures. |

All four: `nonReentrant`, `ownerOnlySender`, `onlyActiveFleetCommander×2`, run
`_validateStrategyConfig`, enforce `DuplicateStrategy`, assign
`id = _nextStrategyId++`, set `ACTIVE`, emit `StrategyCreated(id, config)`.

The `*WithPermit2` create paths also run `_requirePermit2CoversStrategy`:
- `permitSingle.details.amount ≥ tradeAmount * maxTrades` (`Permit2AllowanceInsufficient`)
- if `endDate > 0`: `permitSingle.details.expiration ≥ endDate` (`Permit2ExpirationTooEarly`)

### Manage (all `nonReentrant`, `onlyStrategyOwner`)

| Function | State guard | Effects | Event |
|----------|-------------|---------|-------|
| `editStrategy(id, oldConfig, newConfig)` | non-terminal; `onlyActiveFleetCommander×2` on `newConfig` | re-validate; reject owner change (`UnauthorizedAccess`); reject `DuplicateStrategy`; swap commitment; `nextTriggerAt = lastScheduledAt + newConfig.interval`; may auto-complete | `StrategyEdited`, maybe `StrategyCompleted` |
| `pauseStrategy(id, config)` | must be `ACTIVE` (`StrategyNotActive`) | `status = PAUSED` | `StrategyPaused(id, nextTriggerAt)` |
| `resumeStrategy(id, config)` | must be `PAUSED` (`StrategyNotActive`) | `status = ACTIVE`; `lastScheduledAt = now`; `nextTriggerAt = now + interval` | `StrategyResumed(id, nextTriggerAt)` |
| `cancelStrategy(id, config)` | non-terminal | `status = CANCELLED` | `StrategyCancelled(id)` |

### Execute (`onlyKeeper`, `nonReentrant`, `onlyActiveFleetCommander×2`)

`executeStrategy(id, config, ensoData)` — see §7 for the full sequence. Pre-flight:
commitment match → must be `ACTIVE` → if `tradesExecuted ≥ maxTrades` or
`endDate` reached, mark COMPLETED and **return without reverting** → else require
`block.timestamp ≥ nextTriggerAt` (`ExecutionWindowNotReached`).

### Views

- `strategyStates(id) → StrategyState`
- `strategyCommitments(id) → bytes32` (auto-getter)
- `activeCommitments(hash) → bool` (auto-getter)
- `checkUpkeep(id, config) → (bool upkeepNeeded, bytes performData)` — returns
  `(false, "")` on commitment mismatch, non-ACTIVE, window-not-reached, maxTrades
  exhausted, endDate passed, or price out of `[minPrice, maxPrice]`. `performData`
  is **always empty** — the keeper computes `ensoData` off-chain.

---

## 7. Execution semantics & math

`executeStrategy` → `_executeStrategy` → `_executeSwap`. The full path
(`DCAStrategyManager.sol:643-802`):

**A. Price & minOut (view math, before any transfer):**
1. `intendedInAssets = sourceVault.convertToAssets(tradeAmount)` — shares → underlying in-asset.
2. `(expectedOutAssets, inPrice, outPrice) = ChainlinkOracleUtils.convertAmount(intendedInAssets, inAsset, inAssetFeed, outAsset, outAssetFeed)` — `inAssetFeed`/`outAssetFeed` are `ChainlinkFeed{feed, maxStaleness}` structs.
3. `executionPrice = crossRate(inPrice, outPrice)` — 1e18-scaled out-asset price in in-asset units.
4. Price guard: revert `PriceAboveCeiling` if `maxPrice > 0 && executionPrice > maxPrice`; revert `PriceBelowFloor` if `minPrice > 0 && executionPrice < minPrice`.
5. `expectedOutShares = targetVault.previewDeposit(expectedOutAssets)`; if `0` → revert `ZeroExpectedOutShares`.
6. `minOut = expectedOutShares.subtractBps(slippageBps)` = `expectedOutShares * (10000 - slippageBps) / 10000`.

**B. Effects (before interaction — CEI):**
7. Capture `sourceSharesBaseline = sourceShares.balanceOf(this)`.
8. `_pullFunds(owner, sourceVault, tradeAmount)` — Permit2 `transferFrom` of `tradeAmount` source shares from owner.
9. `nextTriggerAt = block.timestamp + interval`; `tradesExecuted += 1`; `lastScheduledAt = block.timestamp`.

**C. Interaction:**
10. `targetSharesBefore = targetShares.balanceOf(this)`.
11. `_ensoSwap(sourceVault, tradeAmount, ensoData)` — approve Enso for `tradeAmount`, low-level `call(ensoData)`, reset approval to 0.
12. `swappedAmount = targetShares.balanceOf(this) - targetSharesBefore`.
13. Require `swappedAmount ≥ minOut` (else `SwapOutputBelowMinOut`).
14. `targetShares.safeTransfer(owner, swappedAmount)`.
15. Refund: `residue = max(0, sourceShares.balanceOf(this) - sourceSharesBaseline)`; if `> 0`, `safeTransfer(owner, residue)`. `actualInShares = tradeAmount - residue`.
16. `outAssets = targetVault.convertToAssets(swappedAmount)`.

**D. Lifecycle (in `_executeStrategy`):**
17. Emit `ExecutionCompleted(id, tradesExecuted, actualInShares, swappedAmount, sourceVault.convertToAssets(actualInShares), outAssets, nextTriggerAt)`.
18. If `tradesExecuted ≥ maxTrades` → `_markCompleted(id, "max_trades")`; else if `endDate > 0 && nextTriggerAt ≥ endDate` → `_markCompleted(id, "end_date")`.

**Price-unit conventions:**
- `crossRate` returns `(outPrice/outScale) / (inPrice/inScale) × 1e18` = **price of the out-asset denominated in the in-asset, ×1e18**. So for ETH(out)/USDC(in), `executionPrice ≈ 3000e18` means 1 ETH ≈ 3000 USDC. `maxPrice` is the "don't pay more than" ceiling; `minPrice` the "don't sell below" floor.
- `convertAmount` normalises both oracle decimals and token decimals via a single `mulDiv` (no intermediate rounding).

---

## 8. Integration guide

### 8.1 Approvals & Permit2 (keeper-driven recurring pulls)

The contract **never** holds a standard ERC20 approval from the user. Recurring
pulls go through Permit2 `AllowanceTransfer`. Required one-time setup by the owner:

1. `sourceVaultShares.approve(PERMIT2, type(uint256).max)` — standard ERC20, once.
2. Grant the manager a sub-allowance, either:
   - on-chain: `PERMIT2.approve(sourceVaultShares, manager, amount, expiration)`, **or**
   - by signing a `PermitSingle` and using a `*WithPermit2` create path (manager
     calls `PERMIT2.permit` in-tx via `_applyPermit2Allowance`).

Sizing the sub-allowance: cover `tradeAmount * maxTrades`, and set `expiration ≥
endDate` (the `*WithPermit2` paths enforce both up front). `amount` must fit in
`uint160`.

> `_applyPermit2Allowance` wraps `PERMIT2.permit` in try/catch: a mempool
> front-run that independently submits the user's signed permit (causing an
> `InvalidNonce` in-tx) is tolerated **iff** the resulting on-chain sub-allowance
> already covers the signed amount; otherwise it reverts `Permit2AllowanceNotSet`.

### 8.2 The one-shot deposit paths

- `depositAndCreate`: owner pre-approves `inAsset → manager` (ERC20); manager
  `safeTransferFrom` → `forceApprove(sourceVault, amount)` → `sourceVault.deposit(amount, owner)` → `forceApprove(0)`. **Source shares land in the owner's wallet**, not the manager.
- `depositAndCreateWithPermit2`: same effect, but the `inAsset` pull is a Permit2
  `SignatureTransfer` (`_pullFundsWithPermit2`, validates token+amount) and the
  recurring share allowance is set from the bundled `PermitSingle`.

### 8.3 Managing — always resubmit the exact current config

Edit/pause/resume/cancel all require the current `StrategyConfig` (and, for edit,
the new one). Keep the latest config in sync with the last `StrategyCreated` /
`StrategyEdited` event. Owner cannot be changed via edit.

### 8.4 Keeper integration

1. Poll `checkUpkeep(id, config)`; act when `upkeepNeeded == true`. (Note: price
   guards are re-checked on-chain at execution — see §13, price race.)
2. Build `ensoData` off-chain: a route that swaps `tradeAmount` **source-vault
   shares** into **target-vault shares**, delivered to the manager. The manager
   approves Enso for exactly `tradeAmount` source shares before the call.
3. Compute an expected output and ensure it clears the on-chain `minOut`
   (`expectedOutShares × (1 − slippageBps)`); otherwise the tx reverts
   `SwapOutputBelowMinOut`.
4. Call `executeStrategy(id, config, ensoData)`.

---

## 9. Scheduling & timing model

| Event | `nextTriggerAt` set to | `lastScheduledAt` |
|-------|------------------------|-------------------|
| Create | `_hourAlignedTimestamp() + interval` (rounds up to next whole hour) | `_hourAlignedTimestamp()` |
| Execute | `block.timestamp + interval` | `block.timestamp` |
| Resume | `block.timestamp + interval` | `block.timestamp` |
| Edit | `lastScheduledAt + newConfig.interval` (NOT touched at edit) | unchanged |

> **Edit can place the trigger in the past.** If `lastScheduledAt + newInterval <
> block.timestamp`, the strategy is immediately executable after the edit. This
> is by design (a shorter interval should take effect promptly) but integrators
> should expect a possible instant execution after a downward interval edit.

Auto-complete reasons (bytes32): `"max_trades"`, `"end_date"`.

---

## 10. Events (indexer contract)

| Event | Signature |
|-------|-----------|
| `StrategyCreated` | `(uint256 indexed id, StrategyConfig config)` |
| `StrategyEdited` | `(uint256 indexed id, StrategyConfig config)` |
| `StrategyPaused` | `(uint256 indexed id, uint256 nextTriggerAt)` |
| `StrategyResumed` | `(uint256 indexed id, uint256 nextTriggerAt)` |
| `StrategyCancelled` | `(uint256 indexed id)` |
| `StrategyCompleted` | `(uint256 indexed id, bytes32 reason)` |
| `ExecutionCompleted` | `(uint256 indexed id, uint256 tradesExecuted, uint256 inShares, uint256 outShares, uint256 inAssets, uint256 outAssets, uint256 nextTriggerAt)` |

`ExecutionCompleted` field mapping: `inShares = actualInShares` (tradeAmount minus
refunded residue), `outShares = swappedAmount`, `inAssets =
sourceVault.convertToAssets(inShares)`, `outAssets =
targetVault.convertToAssets(outShares)`. On a completing trade, the order is
`ExecutionCompleted` then `StrategyCompleted`.

> ABI/wire reminder: regenerate the FE + subgraph ABIs on any interface change
> (see `CLAUDE.md` "Quick commands"). The struct's 14-field order is part of the
> commitment and must match everywhere.

---

## 11. Errors (selector reference)

Defined in `IDCAStrategyManagerErrors` (plus `EnsoRouterSwapper`,
`Permit2Consumer`, `HarborCommandConsumer`, `ChainlinkOracleUtils`,
`ProtocolAccessManaged`).

Validation: `InvalidOwner`, `SameAsset`, `InAssetVaultMismatch`,
`OutAssetVaultMismatch`, `IntervalTooShort`, `IntervalTooLong`, `InvalidSlippage`,
`ZeroTradeAmount`, `ZeroMaxTrades`, `InvalidFeedAddress`, `InvalidPriceBounds`,
`ZeroDeposit`.
Ownership/lifecycle: `CommitmentMismatch`, `DuplicateStrategy`, `StrategyNotActive`,
`UnauthorizedAccess`, `UnauthorizedOwner`, `ExecutionWindowNotReached`.
Execution: `SwapOutputBelowMinOut`, `ZeroExpectedOutShares`, `PriceAboveCeiling`,
`PriceBelowFloor`, `SwapFailed`, `EmptySwapData`.
Permit2: `Permit2AllowanceInsufficient`, `Permit2ExpirationTooEarly`,
`InvalidPermit2Token`, `InvalidPermit2Spender`, `InvalidPermit2Amount`,
`Permit2AllowanceNotSet`, `AmountOverflowsUint160`.
Oracle: `ChainlinkOraclePriceZero`, `ChainlinkOracleStalePrice`.
Registry/roles: `InactiveFleetCommander`, `CallerIsNotKeeper`.

---

## 12. Invariants (maintainer source of truth — see `CLAUDE.md`)

1. **Commitment is the ownership proof.** No owner mapping; `keccak256(abi.encode(config))` + `msg.sender == owner`.
2. **`strategyId` is the mapping key only, never inside the hash.**
3. **Duplicate prevention is O(1); terminal states do NOT free the hash.**
4. **Ownership transfer via edit is disallowed.**
5. **Auto-COMPLETED** after the last valid execution (`tradesExecuted ≥ maxTrades` or `nextTriggerAt ≥ endDate`); subsequent keeper calls revert `StrategyNotActive`.
6. **Effects before interactions**; Enso allowance reset to 0 even on underspend.
7. **No standing ERC20 approval from users** — pulls are 100% Permit2.
8. **No funds held across transactions** — residue above the captured baseline is refunded to the owner each trade.

---

## 13. Security model & considerations (for reviewers)

### Trust boundaries
- **Keeper** (semi-trusted): chooses *when* (within the schedule/price window) and
  *how* (the Enso route) a trade executes. Bounded by: `onlyKeeper`, the
  `minOut`/price guards, and the fact that whatever target shares *reach the
  manager* are forwarded to `config.owner`. **Not bounded** against: ordering/MEV,
  choosing a sub-optimal-but-passing route, or simply not executing (liveness).
  ⚠️ **Crucially**, `minOut` is only a floor on what the route delivers to the
  manager — it does not prove the route sent *all* proceeds there. A malicious
  keeper can deliver exactly `minOut` and keep the rest (up to `slippageBps` of
  expected output per trade). The external review flags this as the top issue —
  see **C-1 in §15**.
- **Oracle** (trusted within 24h): `MAX_ORACLE_STALENESS = 86400`. Any round
  fresher than 24h is trusted as-is; no deviation/sequencer-uptime check.
- **Enso router** (trusted code, untrusted calldata): `ensoData` is forwarded
  verbatim via low-level `call`. The contract only checks the *target-share
  balance delta* against `minOut` and resets the source approval to 0.
- **HarborCommand** (trusted): gates which vaults are valid at create/edit **and
  execute** time.

### Residual considerations / reviewer checklist
| Topic | Note |
|-------|------|
| Vault deregistration | `executeStrategy` carries `onlyActiveFleetCommander` on both vaults, so a deregistered vault **freezes execution** (reverts `InactiveFleetCommander`) rather than allowing it. The owner can still `cancel`. Confirm this liveness behaviour is intended. (Supersedes lead L-4 in the 2026-05-26 review, which predates the modifier on execute.) |
| Read-only reentrancy | Pricing uses `convertToAssets` / `previewDeposit` on the vaults. Confirm these can't be manipulated mid-call by a reentrant path through the Enso `call`. The transient reentrancy guard protects the manager's own externals, not cross-contract view manipulation. |
| Vault share inflation / donation | `convertToAssets` (step A.1) and `previewDeposit` (A.5) feed `minOut`. Assess donation/inflation attacks on either vault that skew the expected amount and thus the floor. |
| Price race | `checkUpkeep` and `executeStrategy` read oracles in separate txs; price may cross a bound between them. Execution re-checks on-chain, so a stale `checkUpkeep` pass simply reverts (`PriceAbove/BelowCeiling/Floor`). |
| Slippage band abuse | `minOut` derives from the oracle expectation, not a live quote. With a loose `slippageBps` the keeper has room to extract value within the band. UI should default tight. |
| Overflow | `tradeAmount * maxTrades` in `_requirePermit2CoversStrategy` is a plain `uint256` multiply (0.8.x checked → reverts on overflow rather than wrapping). Oracle math uses `mulDiv`; confirm no plain multiplies overflow for high-decimal assets/large amounts (lead L-1). |
| Permit2 front-run | `_applyPermit2Allowance` tolerates a front-run only when the resulting sub-allowance covers the signed amount; otherwise reverts. |
| `tradeAmount > uint160` | Rejected at pull time (`AmountOverflowsUint160`), but `_validateStrategyConfig` does not bound `tradeAmount` to `uint160` at create — a too-large `tradeAmount` creates a strategy that can never execute. |

### Remediated since the 2026-05-26 review (see §14)
F-1…F-5 are all fixed in the current code (gated creation, terminal-edit block,
COMPLETED→CANCELLED block, 50% slippage cap, oracle staleness check).

---

## 14. Audit scope & prior-review status

**Files in scope:**

| File | Role |
|------|------|
| `contracts/DCA/DCAStrategyManager.sol` | Main contract (~300 nSLOC) |
| `utils/EnsoRouterSwapper.sol` | Enso approve→call→reset |
| `utils/Permit2Consumer.sol` | Permit2 Allowance/Signature transfers |
| `utils/HarborCommandConsumer.sol` | Vault registry gate |
| `utils/ChainlinkOracleUtils.sol` | Oracle math + staleness |
| `interfaces/arks/IDCAStrategyManager.sol` | Types + signatures |
| `errors/arks/IDCAStrategyManagerErrors.sol` | Errors |
| `events/arks/IDCAStrategyManagerEvents.sol` | Events |

**Reviews.** The 2026-05-26 external review (Pashov `solidity-auditor` skill)
raised F-1 (permissionless creation), F-2 (oracle staleness), F-3 (terminal-edit
frees commitment), F-4 (COMPLETED→CANCELLED), F-5 (100% slippage) — **all
remediated** in the current source (its lead L-4 is superseded; execute now carries
the registry modifier — see §13). The fresh **AI adversarial audit** (2026-06-03,
Gemini + GPT-5.5 + source verification) is the current finding set; see §15 and the
full writeup in [`DCAStrategyManager.ai-audit.md`](./DCAStrategyManager.ai-audit.md).

---

## 15. AI security audit (summary)

The fresh adversarial findings (2026-06-03 — Gemini `gemini-3.1-pro-preview` +
OpenAI `gpt-5.5`, with a Claude-led source verification) are maintained in their
own companion doc, which is the **canonical** writeup:
**[`DCAStrategyManager.ai-audit.md`](./DCAStrategyManager.ai-audit.md)**.

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| C-1 | Keeper can route swap surplus to itself (`minOut` is not a floor vs. the keeper) | High | **Risk accepted — keeper trusted** |
| C-2 | `minOut` can round to zero for tiny expected-share counts | Low | Open (defense-in-depth) |
| C-3 | `checkUpkeep` doesn't mirror `executeStrategy` preconditions | Medium | Open |
| X-1 | Permit2 fallback ignores allowance expiration | Low | Open |
| G-1 | Execution schedule drifts off hour alignment | Info | Open |

**C-1 is risk-accepted:** the keeper is a trusted, permissioned role
(`KEEPER_ROLE` / `SUPER_KEEPER_ROLE`), so `minOut` is treated as a slippage bound
for an honest keeper. Revisit if keepers ever become permissionless. The
FleetCommander verification (in the audit doc) downgrades C-2's inflation
amplifier. See §13 (keeper trust) and §9 (edit-trigger timing) for the
integrator-facing angles.

<details>
<summary>Appendix — original two-model writeup (2026-06-03; superseded by the audit doc above)</summary>

> Retained for reference. The audit doc is authoritative; C-1 has since been
> risk-accepted (keeper trusted).

### Consensus finding (both models — HIGH)

**C-1 — The keeper's arbitrary Enso route makes `minOut` a profit margin, not a
safety floor.** `_executeSwap` (`DCAStrategyManager.sol:771-786`) approves
`tradeAmount` source shares to Enso, forwards opaque keeper-supplied `ensoData`,
and only checks the manager's *target-share balance delta ≥ minOut*. It never
constrains where the route sends value. A malicious or compromised keeper can
route the full pulled amount, deliver exactly `minOut` target shares to the
manager, and direct the surplus to itself — every trade, deterministically.

- `minOut = expectedOutShares × (1 − slippageBps)`. With the 50% cap, a keeper can
  skim up to **~50% of expected output per trade** and still pass. Even a tight
  `slippageBps` is a per-trade skim ceiling, not a one-off MEV risk.
- The 24h oracle staleness window widens the gap between `minOut` and the *live*
  market price, so the capturable surplus can exceed the user's intended slippage.
- Codex confidence 0.86; Gemini confidence 1.0 (framed via target-vault inflation).

**Why it matters:** the design treats the keeper as "bounded by `minOut`." In
reality the keeper is trusted with up to `slippageBps` of every trade. This must
be an explicit, accepted assumption — or mitigated.

**Mitigation directions (to evaluate):** don't forward arbitrary router calldata
for user-owned swaps — prefer a constrained wrapper where the manager supplies
`(tokenIn, tokenOut, amount, recipient = address(this), minOut)` and Enso cannot
redirect output, or decode/whitelist the route and reject any non-manager output
recipient; and verify the floor against a manipulation-resistant price while
forwarding the *full measured* output to the owner.

### Corroborating / amplifying findings

**C-2 — `minOut` can round to zero for small expected-share counts (Codex MEDIUM
0.70; Gemini detail).** The guard rejects `expectedOutShares == 0` but not the
case where `subtractBps` floors a small positive value to `minOut = 0` (e.g.
`expectedOutShares == 1, slippageBps > 0`). A target-vault donation/inflation
attack can push `previewDeposit(expectedOutAssets)` down to 1 → `minOut = 0` → a
zero-output route passes. Fixes: require `minOut > 0` after slippage, round the
floor up, enforce a minimum trade/expected-share size, quote against a
manipulation-resistant share price. *Dependency:* FleetCommander's ERC4626
inflation resistance — **verified, see "Verification against FleetCommander"
below**. C-1 holds regardless; C-2's inflation *amplifier* turns out to be
largely mitigated for FleetCommander, but the `minOut == 0` guard gap is still a
cheap, worthwhile fix.

**C-3 — `checkUpkeep` does not mirror `executeStrategy`'s preconditions (Codex
MEDIUM 0.90; Gemini LOW on the `endDate` sub-case).** `checkUpkeep`
(`DCAStrategyManager.sol:418-458`) omits the active-vault check, the unconditional
oracle/`minOut` computation, the `ZeroExpectedOutShares` path, and Permit2
allowance/expiration & owner-balance checks; it also returns `false` once
`endDate` passes (so the auto-COMPLETE transition is unreachable by a keeper that
only trusts `checkUpkeep`, leaving the strategy ACTIVE-but-dead). Net effects:
(a) false positives → `executeStrategy` reverts → keeper gas-griefing; (b) expired
strategies never reach COMPLETED on-chain. Fix: mirror execution preconditions in
`checkUpkeep` (and surface an `endDate` cleanup signal), or document it as a
partial hint and require keepers to simulate.

### Verification against FleetCommander (2026-06-03)

I traced C-1 and C-2 against the actual source vault, since both findings hinge
on the source/target vaults' ERC4626 internals.

**What FleetCommander is:**
- It inherits **OpenZeppelin's standard `ERC4626`** (`FleetCommander.sol:13,29,49`,
  `constructor … ERC4626(IERC20(params.asset))`) — appreciating shares, standard
  OZ conversion formulas.
- It **does not override `_decimalsOffset()`** → OZ default `0` → the conversion
  math carries OZ's built-in `+1` virtual asset / `+1` virtual share dampener:
  `shares = assets·(totalSupply+1)/(totalAssets+1)` and the inverse.
- It **overrides `totalAssets()`** (`FleetCommander.sol:359`) →
  `_totalAssets(config.bufferArk)` → `FleetCommanderCacheLib.totalAssets` →
  `sumTotalAssets(getAllArks(...))` = the sum of each **Ark's** position plus the
  buffer Ark. **It does not read the vault's own `asset.balanceOf(this)`.**

**Conclusion — C-1 (keeper route surplus skim): CONFIRMED, and independent of
vault internals.** The manager approves `tradeAmount` source shares to Enso and
verifies only the *target-share balance delta ≥ minOut*; it never constrains the
route's output recipient. A malicious/compromised keeper can deliver exactly
`minOut` and divert the rest. This holds for any ERC4626 vault. **Severity gate:
the keeper is permissioned** (`KEEPER_ROLE` / `SUPER_KEEPER_ROLE`, granted by
governance), so this is an insider/compromise threat, not a permissionless one —
but `minOut` is genuinely *not* a safety floor against the keeper. This is the
finding to resolve.

**Conclusion — C-2 (inflation amplifier): LARGELY MITIGATED for FleetCommander.**
The classic "donate tokens to the vault to inflate the share price" move **does
not work**: a direct ERC20 transfer to the FleetCommander address is *uncounted*
because `totalAssets()` reads Ark positions, not the vault's own balance. Add the
OZ `+1/+1` virtual offset, and to force `previewDeposit(expectedOutAssets) → 1`
you would need share price (assets/share) to exceed a whole trade's
`expectedOutAssets`, i.e. a donation on the order of total TVL — economically
irrelevant for any established vault. The only theoretical donation vector is into
the **buffer Ark** (whose `totalAssets()` reads its own balance), and even that is
TVL-gated by the points above; it could only bite a brand-new, near-empty target
vault.

> **Net:** treat C-1 as the real, must-decide issue (keeper trust model). C-2's
> inflation *exploit* is impractical against FleetCommander, but the mechanical
> gap it rides on — the contract rejecting only `expectedOutShares == 0`, never
> `minOut == 0` after `subtractBps` flooring — is still a cheap defense-in-depth
> fix (`require(minOut > 0)`, round-up, minimum trade size), most relevant for new
> or low-TVL target vaults.

### Single-model findings

**G-1 — Schedule drift (Gemini, LOW/info).** Creation hour-aligns `nextTriggerAt`,
but executions set `nextTriggerAt = block.timestamp + interval`, drifting the slot
forward each trade and defeating the alignment. `nextTriggerAt =
state.nextTriggerAt + interval` fixes it (trade-off: can bunch catch-up runs after
a late keeper).

**X-1 — Permit2 fallback ignores allowance expiration (Codex, LOW 0.78).**
`Permit2Consumer._applyPermit2Allowance` (`lines 140-146`) catches a failed
`PERMIT2.permit` and accepts a pre-existing allowance checking only `amount`,
discarding `expiration`. A create can succeed against an old, sufficiently-funded
allowance that expires before `endDate`, so later keeper pulls revert
`AllowanceExpired`. Fix: in the catch path also require on-chain
`expiration ≥ signed expiration` (or `≥ endDate`); ideally suppress only the
specific already-applied-nonce race this path targets.

### What both models agree is NOT broken
- The stateless commitment ownership model is sound; neither found an unprivileged
  path to pull another user's shares (the original F-1 stays fixed).
- Permit2 sub-allowance sizing and Chainlink decimal normalisation are correct.

### Verdicts
- **Codex (`gpt-5.5`):** "not safe under the stated adversarial keeper and
  griefing assumptions"; commitment model sound; root issue is over-trusting the
  keeper's Enso calldata. Overall confidence 0.82.
- **Gemini (`gemini-3.1-pro-preview`):** 9.5/10 architecture; the share-denominated
  `minOut` against a manipulable spot rate is the must-fix before deploy.

### Maintainer takeaways (priority order)
1. **Decide the keeper trust model (C-1).** Either accept "keeper may skim up to
   `slippageBps` per trade" explicitly, or constrain the Enso route (hard-code
   output recipient / whitelist / wrapper) so the floor is a real safety bound.
2. **Harden the floor (C-2):** `minOut > 0`, round-up, minimum trade size.
   (FleetCommander's inflation resistance was verified adequate — see
   "Verification against FleetCommander" — so this is defense-in-depth, chiefly
   for new/low-TVL target vaults.)
3. **Align `checkUpkeep` with execution (C-3)** or document it as a partial hint.
4. **Fix the Permit2 catch-path expiration check (X-1).**
5. **Optional:** rigid scheduling (G-1).

> Provenance: run via the `/second-opinion` skill (Trail of Bits). These are
> independent model opinions; confirm each against the source and the test suite
> before acting.

</details>

---

*Reverse-engineered technical reference. Verify every claim against the source
before relying on it for an integration or audit.*
