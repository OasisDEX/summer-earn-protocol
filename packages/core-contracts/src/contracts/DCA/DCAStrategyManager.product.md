# Product Specification — DCA Strategy Manager

> **Document status:** Reverse-engineered "as-built" specification, derived from
> `DCAStrategyManager.sol` and its interface/events/errors. Written for product
> review and sign-off. It describes **what the deployed logic actually does
> today**, not a forward-looking design.
>
> **Date:** 2026-06-03 · **Source of truth:** `packages/core-contracts/src/contracts/DCA/DCAStrategyManager.sol`
> · **Audience:** Product / non-Solidity stakeholders.
>
> Sections marked **🟠 Needs product sign-off** call out behaviours where the
> current implementation made a choice a product owner should explicitly accept
> or change.

---

## 1. What this is, in one paragraph

The DCA Strategy Manager lets a user set up an automated **dollar-cost-averaging
(DCA)** plan: "every N days, sell a fixed amount of my position in vault A and
move it into vault B." A permissioned bot (the **keeper**) carries out each
scheduled trade. The contract itself **never holds user funds between trades** —
on each execution it pulls exactly the configured amount from the user, routes
it through an external swap aggregator, deposits the proceeds into the
destination vault, and hands the resulting shares straight back to the user, all
in a single transaction. The user stays in full control: they can pause, resume,
edit, or cancel at any time, and only they can do so.

---

## 2. Glossary

| Term | Plain-language meaning |
|------|------------------------|
| **DCA** | Dollar-cost averaging — buying/rotating a fixed amount on a fixed schedule, regardless of price, to smooth out timing risk. |
| **FleetCommander vault** | A Summer.fi yield-bearing vault. Depositing an asset returns **shares**; shares can be redeemed back to the underlying asset. Both the "source" and "target" of a DCA strategy are vaults. |
| **Source vault** | The vault the user is rotating *out of* on each trade. |
| **Target vault** | The vault the user is rotating *into* on each trade. |
| **Shares** | The token representing a position in a FleetCommander vault. A strategy's `tradeAmount` is denominated in **source-vault shares**. |
| **Keeper** | An off-chain bot, authorised by protocol governance, that triggers each scheduled trade. The keeper cannot redirect funds — it can only execute trades the user pre-authorised. |
| **Enso** | The external swap-routing aggregator that performs the actual source→target conversion. |
| **Permit2** | Uniswap's signature-based approval system. It lets the user grant the manager a capped, time-boxed allowance to pull their source shares for scheduled trades — without per-trade approvals. |
| **Chainlink feed** | A price oracle. Used to sanity-check the trade price and compute a minimum acceptable output. |
| **Commitment** | A cryptographic fingerprint (hash) of the strategy's configuration, stored on-chain. It doubles as the strategy's ownership proof (see §4). |

---

## 3. Actors and roles

| Actor | What they can do | How they are authorised |
|-------|------------------|-------------------------|
| **Strategy owner** (end user) | Create, edit, pause, resume, cancel their own strategies. Receives all trade proceeds. | Must be `msg.sender == config.owner`, proven on every call. |
| **Keeper** (bot) | Trigger `executeStrategy` for any strategy when its schedule and price conditions are met. Cannot create, edit, or cancel strategies, and cannot redirect proceeds (they always go to the owner). | Holds the contract's `KEEPER_ROLE`, or the global `SUPER_KEEPER_ROLE`, in the Protocol Access Manager. |
| **Protocol governance** | Grants/revokes keeper roles; registers which vaults are valid (via HarborCommand). | Access-control layer (`ProtocolAccessManaged`). |
| **External: Enso router** | Executes the swap with the shares pulled for a trade. | Fixed at deployment. |
| **External: HarborCommand registry** | Authoritative list of "active" FleetCommander vaults. | Fixed at deployment. |

---

## 4. Core design principles (the non-obvious parts)

These three properties shape almost every behaviour below.

1. **Non-custodial — the contract holds no funds between transactions.** It owns
   no balances. Each trade pulls funds in, swaps, and pushes proceeds out, all
   atomically. If anything in that chain fails, the whole trade reverts and the
   user keeps their position untouched.

2. **Ownership is proven statelessly via a "commitment".** When a strategy is
   created, the contract stores a hash of the full configuration. There is **no
   stored owner→strategy table**. Instead, every owner action requires the
   caller to re-supply the *exact* configuration; the contract re-hashes it,
   checks it matches the stored commitment, and checks `msg.sender` equals the
   `owner` field inside that config. This makes the on-chain footprint tiny but
   means the **frontend/keeper must always know and resubmit the current config
   verbatim** (off by one field = rejected).

3. **Each scheduled trade is fully atomic.** Pull shares → swap via Enso →
   verify minimum output → deliver target shares to owner → refund any unused
   source shares. All in one transaction. The user is never left mid-trade.

---

## 5. Strategy configuration (`StrategyConfig`)

This is what a user defines when creating a strategy. **Every field is part of
the commitment hash**, so changing any field produces a different strategy
identity (and, via edit, requires the duplicate-prevention check to pass).

| Field | Meaning | Constraints (enforced on-chain) |
|-------|---------|----------------------------------|
| `owner` | Address that controls the strategy and receives all proceeds. | Must be non-zero. Must equal the caller at create time. **Cannot be changed by edit** (see §6). |
| `sourceVault` | Vault rotated *out of*. `tradeAmount` shares are pulled from here each trade. | Must be an **active** FleetCommander (HarborCommand registry). Must differ from `targetVault`. |
| `targetVault` | Vault rotated *into*. Proceeds are deposited here. | Must be an active FleetCommander. Must differ from `sourceVault`. |
| `inAsset` | Underlying asset of the source vault (e.g. USDC). Used for price lookups. | Must equal `sourceVault.asset()`. Must differ from `outAsset`. |
| `outAsset` | Underlying asset of the target vault (e.g. ETH). Used for price lookups. | Must equal `targetVault.asset()`. Must differ from `inAsset`. |
| `inAssetFeed` | Chainlink price feed for `inAsset`. | Must be non-zero. |
| `outAssetFeed` | Chainlink price feed for `outAsset`. | Must be non-zero. |
| `tradeAmount` | **Source-vault shares** sold per execution. | Must be > 0. |
| `interval` | Minimum seconds between executions. | **≥ 1 day and ≤ 90 days.** |
| `slippageBps` | Max acceptable slippage, in basis points (10000 = 100%). | **≤ 5000 (50%).** |
| `maxPrice` | Optional price **ceiling** — skip/abort the trade if the out-asset is more expensive than this. `0` = no ceiling. | If both bounds set, `minPrice ≤ maxPrice`. (Units: see note below.) |
| `minPrice` | Optional price **floor** — skip/abort if the out-asset is cheaper than this. `0` = no floor. | As above. |
| `endDate` | Unix timestamp after which no further trades run. `0` = no end date. | Used for auto-completion and Permit2 expiry checks. |
| `maxTrades` | Total number of executions before the strategy auto-completes. | Must be ≥ 1. **There is no "unlimited" sentinel** — a finite cap is always required. |

**Price-bound units (`maxPrice` / `minPrice`):** expressed as the price of the
**out-asset denominated in the in-asset**, scaled to 1e18. Example: buying ETH
(out) with USDC (in), `maxPrice = 5000e18` means *"abort if 1 ETH costs more than
5000 USDC at the oracle."*

> **🟠 Needs product sign-off — `maxTrades` is mandatory and capped by `interval`.**
> A strategy must declare a finite number of trades up front, and because
> `interval ≤ 90 days`, very long-horizon plans require a large `maxTrades`. There
> is no "run forever" option. Confirm this matches the intended product.

> **🟠 Needs product sign-off — `interval` floor of 1 day / ceiling of 90 days.**
> Users cannot DCA more frequently than daily, nor space trades more than ~3
> months apart. Confirm both bounds.

---

## 6. Strategy lifecycle (state machine)

A strategy is always in exactly one of four states:

| State | Meaning | Keeper executes? |
|-------|---------|------------------|
| **ACTIVE** | Live and eligible for scheduled trades. | ✅ |
| **PAUSED** | Temporarily halted by the owner. | ❌ |
| **COMPLETED** | Terminal — ran to its natural end (`maxTrades` hit, or `endDate` passed). | ❌ |
| **CANCELLED** | Terminal — manually ended by the owner. | ❌ |

```
            create
              │
              ▼
        ┌──────────┐  pause   ┌──────────┐
        │  ACTIVE  │ ───────▶ │  PAUSED  │
        │          │ ◀─────── │          │
        └──────────┘  resume  └──────────┘
          │     │                  │
   cancel │     │ maxTrades/endDate │ cancel
          │     │ reached           │
          ▼     ▼                   ▼
     ┌───────────┐  ┌───────────┐
     │ CANCELLED │  │ COMPLETED │   ← both terminal, no exit
     └───────────┘  └───────────┘
```

**Transition rules (as implemented):**

- **Create** → strategy starts **ACTIVE**.
- **Pause** → only from ACTIVE.
- **Resume** → only from PAUSED. On resume, the clock is **reset**: next trade is
  `now + interval`.
- **Cancel** → allowed from ACTIVE or PAUSED. **Blocked** once terminal (cannot
  cancel an already COMPLETED or CANCELLED strategy).
- **Edit** → allowed from ACTIVE or PAUSED only; **blocked** once terminal.
- **Auto-complete** → the strategy flips to COMPLETED automatically when, after a
  trade (or at edit time), `tradesExecuted ≥ maxTrades` (reason `"max_trades"`)
  or `endDate` has been reached (reason `"end_date"`).

> **🟠 Needs product sign-off — terminal strategies are permanent and their
> identity is locked.** A COMPLETED/CANCELLED strategy cannot be revived. To run
> "the same" plan again the user must create a new strategy, and because the
> commitment hash is never freed for terminal states, the new strategy must
> differ in at least one field (e.g. a new `endDate`). Confirm the UX handles
> "create a fresh strategy" rather than "restart this one."

> **🟠 Needs product sign-off — pause does not extend `endDate`.** If a user
> pauses for a month, the `endDate` does not shift. A long pause can cause the
> strategy to auto-complete on resume/next-check without running all
> `maxTrades`. Confirm this is acceptable.

---

## 7. User flows — creating a strategy

There are **four create entry points**. They differ only in how the user's
approvals and initial deposit are handled; all of them run the same validation
and produce the same ACTIVE strategy.

| Entry point | What it does | When to use |
|-------------|--------------|-------------|
| `createStrategy(config)` | Registers the strategy only. Assumes the user already holds source-vault shares and has set up the Permit2 allowance separately. | User already has a vault position. |
| `depositAndCreate(config, assetAmount)` | Pulls `assetAmount` of the underlying `inAsset` from the user (standard ERC-20 approval), deposits it into the source vault (**shares go straight to the user**), and registers the strategy — one transaction. | User holds the underlying asset, not yet vault shares. |
| `createStrategyWithPermit2(config, permit, sig)` | Like `createStrategy`, but also sets up the recurring keeper allowance via a signed Permit2 message — no separate approval tx. | Gasless/streamlined approval. |
| `depositAndCreateWithPermit2(config, assetAmount, permits)` | Combines the deposit **and** the recurring allowance, both via signed Permit2 messages — one transaction, two signatures. | Fully streamlined onboarding from the underlying asset. |

**Scheduling at creation:** the first trade is scheduled at the **next whole-hour
boundary + `interval`**. Rounding to the hour reduces keeper scheduling churn
across many strategies.

**Permit2 pre-flight checks** (the `*WithPermit2` flows): the signed allowance
must cover the **worst case** (`tradeAmount × maxTrades`) and, if `endDate` is
set, must not expire before `endDate`. This catches misconfigured approvals at
create time rather than failing silently mid-strategy.

**Duplicate prevention:** two identical configurations cannot both be active at
once. The second create reverts with `DuplicateStrategy`.

---

## 8. User flows — managing a strategy

All of these require the caller to be the owner and to resubmit the exact current
config (see §4).

| Action | Effect |
|--------|--------|
| **Edit** (`editStrategy`) | Replace the config with a new one. Re-validates everything, re-points the schedule (`nextTriggerAt = lastScheduledAt + newInterval`), and may auto-complete if the new config is already past its limits. **Cannot change the owner** (transfer is disallowed — cancel and recreate instead). Cannot collide with another active strategy. |
| **Pause** (`pauseStrategy`) | ACTIVE → PAUSED. Stops all keeper trades. |
| **Resume** (`resumeStrategy`) | PAUSED → ACTIVE. Resets the schedule to `now + interval`. |
| **Cancel** (`cancelStrategy`) | → CANCELLED (terminal). Permanent. |

> **🟠 Needs product sign-off — ownership transfer is intentionally impossible.**
> A user cannot hand a strategy to another address. Confirm the product does not
> need transferable strategies.

---

## 9. Execution flow (what the keeper triggers)

When `checkUpkeep` says a strategy is due, the keeper calls `executeStrategy`. A
single execution does the following, atomically:

1. **Verify** the supplied config matches the stored commitment, the strategy is
   ACTIVE, the schedule window has been reached, and limits are not exhausted.
   (If `maxTrades`/`endDate` is already exceeded, the strategy is quietly marked
   COMPLETED instead of reverting.)
2. **Price the trade** using Chainlink: compute the expected out-asset amount and
   the current execution price.
3. **Enforce price guards** — abort if the price is above `maxPrice` or below
   `minPrice` (when set).
4. **Compute the slippage floor** — the minimum acceptable target-vault shares
   (`expected × (1 − slippageBps)`). If the expected output rounds to zero
   shares, the trade is refused outright.
5. **Pull** exactly `tradeAmount` source-vault shares from the owner (via
   Permit2).
6. **Advance state first** (trade counter, next trigger time) — *before* the
   external swap, to prevent re-entrancy abuse.
7. **Swap** the pulled shares through Enso using keeper-provided routing data.
8. **Verify** the received target shares meet the slippage floor — otherwise
   revert the whole trade.
9. **Deliver** the target shares to the owner.
10. **Refund** any source shares the router didn't actually consume back to the
    owner (defends the "no funds held" invariant against routers that underspend).
11. **Emit** `ExecutionCompleted`, and flip to COMPLETED if this was the last
    trade.

**The keeper cannot steal funds:** proceeds always go to `config.owner`, the
amount pulled is capped at `tradeAmount`, and the slippage floor caps how bad a
trade the keeper can route. See §12 for the residual trust boundary.

---

## 10. Price protection — the three guards

A trade is protected by three independent mechanisms:

1. **Price ceiling (`maxPrice`)** — don't buy when the out-asset is too expensive.
2. **Price floor (`minPrice`)** — don't sell when the out-asset is too cheap.
3. **Slippage floor (`slippageBps`)** — regardless of oracle price, the actual
   shares received must be within `slippageBps` of the oracle-derived expectation,
   or the trade reverts.

Guards 1 and 2 are also checked off-chain by `checkUpkeep`, so the keeper simply
skips a strategy whose price is out of range rather than wasting a reverting
transaction.

> **🟠 Needs product sign-off — default slippage cap is 50%.** The contract only
> *rejects* `slippageBps > 5000`. A user (or the UI default) could set a very
> loose slippage. Confirm the UI enforces a sensible, tighter default and warns
> on high values.

---

## 11. Events (for UI / subgraph / notifications)

| Event | Emitted when | Key data |
|-------|--------------|----------|
| `StrategyCreated` | Any create flow succeeds. | `strategyId`, full `config`. |
| `StrategyEdited` | Edit succeeds. | `strategyId`, new `config`. |
| `StrategyPaused` | Owner pauses. | `strategyId`, `nextTriggerAt`. |
| `StrategyResumed` | Owner resumes. | `strategyId`, new `nextTriggerAt`. |
| `StrategyCancelled` | Owner cancels. | `strategyId`. |
| `StrategyCompleted` | Strategy reaches a terminal end. | `strategyId`, `reason` (`"max_trades"` / `"end_date"`). |
| `ExecutionCompleted` | Each successful trade. | `strategyId`, trade #, in/out **shares**, in/out **assets**, next trigger time. |

These events are the contract for the off-chain indexer, keeper bot, and app —
they fully describe a strategy's history.

---

## 12. Trust assumptions & known limitations

These are inherent to the current design. Items previously raised in the
2026-05-26 security review (permissionless creation, terminal-state commitment
freeing, COMPLETED→CANCELLED, slippage = 100%, oracle staleness) **have been
remediated** in the deployed logic. The following are the *residual* assumptions
a product owner should be aware of.

| # | Assumption / limitation | Why it matters |
|---|--------------------------|----------------|
| T-1 | **Keeper liveness is trusted.** If no authorised keeper runs, no trades happen. The contract cannot self-execute. | A user's DCA plan silently stalls if keepers are down. Needs monitoring/SLAs. |
| T-2 | **Keeper supplies the swap route (`ensoData`).** The keeper chooses the path through Enso; the only on-chain protection is the slippage floor and price guards. | A faulty/malicious route is bounded by `minOut`, but a loose `slippageBps` widens that bound (see §10). |
| T-3 | **Oracle freshness window is 24 hours.** Prices older than `MAX_ORACLE_STALENESS` (86 400 s) revert, but anything fresher is trusted. | For volatile assets a 24h-old price can still misprice a trade. Confirm the window suits the assets in scope. |
| T-4 | **Vault validity is checked only at create/edit time.** If a vault is later removed from the HarborCommand registry, existing strategies referencing it can still execute. | A deprecated vault keeps trading until the owner cancels/edits. |
| T-5 | **Price can move between `checkUpkeep` and `executeStrategy`.** They run in separate transactions. | A trade that looked in-range when scheduled may revert (or, within the slippage band, execute) when actually run. |
| T-6 | **Config must be tracked off-chain.** Because ownership is proven by resubmitting the exact config, the app/keeper must persist and resubmit it byte-for-byte; the chain stores only the hash. | Loss of the stored config (or any drift) makes a strategy unmanageable until reconstructed from events. |

---

## 13. Summary of decisions needing product sign-off

Consolidated from the 🟠 callouts above:

1. **No "run forever" mode** — `maxTrades` is mandatory and finite (§5, §6).
2. **Interval bounds 1–90 days** — no sub-daily or >3-month cadence (§5).
3. **Terminal strategies are permanent and non-restartable**; re-running means a
   new (slightly different) strategy (§6).
4. **Pause does not extend `endDate`** — long pauses can cut a plan short (§6).
5. **Ownership is non-transferable** (§8).
6. **50% slippage cap is the only on-chain limit** — UI must enforce a tighter
   default (§10).
7. **Oracle freshness window is 24h** — confirm suitability per asset (§12, T-3).
8. **Operational dependency on keeper liveness** — needs monitoring (§12, T-1).

---

## 14. Reference — full error list

For completeness; these are the conditions under which a user-facing action is
rejected.

| Error | Triggered by |
|-------|--------------|
| `CommitmentMismatch` | Supplied config doesn't match the stored strategy. |
| `DuplicateStrategy` | An identical active strategy already exists. |
| `StrategyNotActive` | Action requires a state the strategy isn't in (e.g. pausing a non-active strategy, acting on a terminal one). |
| `ExecutionWindowNotReached` | Keeper called before the next scheduled time. |
| `SwapOutputBelowMinOut` | Trade output fell below the slippage floor. |
| `ZeroExpectedOutShares` | Expected output rounds to zero shares — trade refused. |
| `UnauthorizedAccess` / `UnauthorizedOwner` | Caller is not the strategy owner (or edit tried to change the owner). |
| `InvalidSlippage` | `slippageBps > 5000`. |
| `ZeroTradeAmount` / `ZeroMaxTrades` / `ZeroDeposit` | A required amount was zero. |
| `InvalidOwner` | `owner` is the zero address. |
| `SameAsset` | Source and target vault (or in and out asset) are identical. |
| `InAssetVaultMismatch` / `OutAssetVaultMismatch` | Declared asset doesn't match the vault's actual underlying. |
| `IntervalTooShort` / `IntervalTooLong` | Interval outside 1–90 days. |
| `InvalidFeedAddress` | A Chainlink feed address is zero. |
| `PriceAboveCeiling` / `PriceBelowFloor` | Execution price outside configured bounds. |
| `InvalidPriceBounds` | `minPrice > maxPrice`. |
| `Permit2AllowanceInsufficient` / `Permit2ExpirationTooEarly` / `InvalidPermit2Token` | Permit2 signature doesn't cover the strategy's worst-case spend/duration, or names the wrong token. |
| `InactiveFleetCommander` | Source or target vault is not an active, registered vault. |
| `CallerIsNotKeeper` | `executeStrategy` called by a non-keeper. |

---

*Generated as a reverse-engineered spec for product review. Verify against the
contract before relying on any single statement for implementation.*
