# DCAStrategyManager — contract

## Protocol — read me first

This file is meta-Claude memory: a checked-in instruction sheet for whoever
(human or agent) edits the DCA system next. **Update it in the same commit
as any logic or design change.** Drift between this file and the code is
worse than not having it.

When you finish a change anywhere in the DCA system:

1. Re-read the **Invariants** below. If any of them moved, edit them.
2. If a struct shape, function signature, event signature, or error name
   changed, walk the four sibling CLAUDE.md files (this is the canonical
   one — see *Cross-linked siblings* below) and update the affected ones in
   the same commit. The struct/hash rules in this file are the source of
   truth.
3. Append a one-line entry to the **Sign-off** block at the bottom of every
   file you actually modified: `YYYY-MM-DD — author — one-sentence summary`.
   Most-recent on top.
4. Don't rewrite history. If an invariant changes, edit the rule in place
   and record the change in Sign-off — don't leave stale rules behind.

Cross-linked siblings (keep mental sync):

- [keeper](../../../scripts/dca-keeper/CLAUDE.md) — Python bot calling
  `executeStrategy`.
- [subgraph](../../../../summer-earn-dca-subgraph/CLAUDE.md) — Goldsky
  indexer for the events emitted here.
- [app](../../../../summer-earn-dca-app/CLAUDE.md) — Next.js UI for
  create/edit/pause/resume/cancel.

---

User-owned dollar-cost-averaging strategies executed by a permissioned keeper.
The contract holds **no funds** across transactions: the source vault is a
FleetCommander share token; every execution pulls exactly `tradeAmount`
shares from the user via Permit2 `AllowanceTransfer`, routes them through
Enso, deposits the proceeds into the target FleetCommander, and forwards the
resulting shares to the user in the same tx.

A convenience entry point `depositAndCreate(config, assetAmount)` lets a user
deposit the underlying `inAsset` into `config.sourceVault` and register the
strategy in one transaction; the resulting source-vault shares go directly to
`msg.sender`, not to this contract.

## Files

- `DCAStrategyManager.sol` — contract.
- `EnsoRouterSwapper.sol` — abstract base that owns `ENSO_ROUTER`,
  `InvalidRouterAddress`, and `_ensoSwap(tokenIn, amountIn, data)`. Any
  future contract needing Enso routing can inherit this instead of
  copy-pasting the approve → call → reset-allowance pattern.
- `Permit2Consumer.sol` — abstract base for Permit2 `AllowanceTransfer` pulls.
- `../../interfaces/arks/IDCAStrategyManager.sol` — `Status` enum,
  `StrategyConfig` struct, `StrategyState` struct, function signatures.
- `../../errors/arks/IDCAStrategyManagerErrors.sol` — all user-facing reverts
  (note: `InvalidRouterAddress` lives in `EnsoRouterSwapper`, not here).
- `../../events/arks/IDCAStrategyManagerEvents.sol` — `StrategyCreated`,
  `StrategyEdited`, `StrategyPaused`, `StrategyResumed`, `StrategyCancelled`,
  `StrategyCompleted`, `ExecutionCompleted`.
- `test/arks/DCAs/DCAsStrategyManager.t.sol` — Foundry unit + fork integration
  tests. **Bug fixes land here first — TDD.** Every error path has a negative
  test; assertions use `IDCAStrategyManagerErrors.X.selector` /
  `abi.encodeWithSelector`, never string signatures (compile-time safety).

## Invariants

- **Commitment IS the ownership proof.** `keccak256(abi.encode(config))` is
  stored as `_strategyCommitments[strategyId]`. Every owner-gated function
  takes `StrategyConfig calldata`, recomputes the hash, checks it against the
  stored commitment, then checks `msg.sender == config.owner`. There is no
  `_strategyOwners` mapping.
- **`strategyId` is the mapping key only — NOT inside the hashed payload.**
  It's an explicit argument to `editStrategy`/`pauseStrategy`/`resumeStrategy`/
  `cancelStrategy`/`executeStrategy`/`checkUpkeep`. The wire encoding of
  `StrategyConfig` must mirror this everywhere (subgraph, app, keeper).
- **Duplicate prevention is O(1).** `_activeCommitments[hash] = true` on
  create/edit; the lookup blocks identical resubmissions. **Terminal states
  (Cancelled/Completed) do NOT free the entry** — the user gets a fresh hash
  naturally because real edits change at least one field (e.g. a new
  `endDate`).
- **Ownership transfer via edit is disallowed.** `editStrategy` reverts with
  `UnauthorizedAccess` when `newConfig.owner != oldConfig.owner`.
- **Auto-COMPLETED transition.** After the last valid execution
  (`tradesExecuted >= maxTrades` OR `nextTriggerAt >= endDate`),
  `_executeSwapCore` flips status to `COMPLETED` and emits
  `StrategyCompleted(id, reason)`. Subsequent keeper calls revert with
  `StrategyNotActive`, not `TerminalStateReached`.
- **Effects-before-interactions.** State writes (`tradesExecuted`,
  `nextTriggerAt`, `lastScheduledAt`) happen *before* the Enso `call`. The
  router allowance is reset to zero post-swap even when the router
  underspends (regression-tested).
- **Permit2 allowance is one-way.** The contract never holds ERC20 approvals
  for the user; it relies entirely on `PERMIT2.transferFrom`. The user must
  approve `sourceVault → Permit2` (standard ERC20) and `Permit2 → manager`
  (via `Permit2.approve` or signed `permit`).

## When changing the struct or hashed payload

You break commitment compatibility for every live strategy. Update in
lockstep:

- This contract + interface + events ABI.
- `../../../scripts/dca-keeper/` — see [`CLAUDE.md`](../../../scripts/dca-keeper/CLAUDE.md).
- `/packages/summer-earn-dca-subgraph/` — see [`CLAUDE.md`](../../../../summer-earn-dca-subgraph/CLAUDE.md).
- `/packages/summer-earn-dca-app/` — see [`CLAUDE.md`](../../../../summer-earn-dca-app/CLAUDE.md)
  (specifically `src/lib/strategy/commitment.ts`, `encode.ts`,
  `types/strategy.ts`, `abis/DCAStrategyManager.ts`).

## Quick commands

```
pnpm --filter @summerfi/core-contracts forge build
pnpm --filter @summerfi/core-contracts forge test --match-contract DCAStrategyManager
# Regen the FE + subgraph ABIs after any interface change:
jq '.abi' out/DCAStrategyManager.sol/DCAStrategyManager.json \
  > ../../../../summer-earn-dca-subgraph/abis/DCAStrategyManager.json
# (then wrap in `export const dcaStrategyManagerAbi = ... as const` for the FE)
```

## Sign-off

<!-- One line per material change. Most recent on top.
Format: YYYY-MM-DD — author — one-sentence summary. -->

- 2026-06-19 — claude — audit KE-3: `checkUpkeep` now returns `false` when the
  owner's source-vault share balance or live Permit2 sub-allowance (amount or
  expiration) can't cover the next `tradeAmount` pull, so the keeper avoids
  doomed executions. View-only; no struct/ABI/wire changes. Tests added in
  `DCAsStrategyManager.t.sol` (`test_CheckUpkeep_ReturnsFalseWhen{ShareBalanceTooLow,AllowanceTooLow,AllowanceExpired}`);
  `test_CheckUpkeep_ReturnsTrueWhenReady` now funds + approves the owner.
- 2026-05-27 — claude — product alignment + DRY pass.
  Validation: `_MAX_INTERVAL = 90 days` cap (new `IntervalTooLong` error);
  `maxTrades == 0` rejected (new `ZeroMaxTrades` error); `maxTrades >= 1` is
  now a contract invariant and the `config.maxTrades > 0 &&` short-circuits
  in `executeStrategy` / `checkUpkeep` / `_executeSwap` are dropped.
  New entrypoint `depositAndCreate(config, assetAmount)` pulls `inAsset` from
  `msg.sender` (standard ERC20 allowance) and deposits to `config.sourceVault`
  with `receiver = msg.sender` in one tx; new `ZeroDeposit` error.
  `ExecutionCompleted` event extended with `inAssets` / `outAssets` and
  renamed `inAmount`/`outAmount` → `inShares`/`outShares` — ABI break,
  subgraph + app + keeper need regenerated ABIs.
  Internal restructure: `_executeStrategy` now owns trade-summary event
  emission AND the terminal-state transition (event order
  `ExecutionCompleted` → `StrategyCompleted` preserved); `_executeSwap` is
  pure swap mechanics. Extracted DRY helpers `_createStrategy`,
  `_depositToFleetCommander`, `_requireNonTerminal`, `_markCompleted`.
  Comment/natspec cleanup pass: removed AI-style narrative comments, dropped
  resolved `@audit` TODO on `resumeStrategy`, fixed stale revert lists.
- 2026-05-26 — claude — extracted Enso approve → call → reset-allowance
  pattern into `EnsoRouterSwapper` abstract contract; `DCAStrategyManager`
  now inherits it. `InvalidRouterAddress` moved from `IDCAStrategyManagerErrors`
  to `EnsoRouterSwapper`. No ABI or wire-format changes.
- 2026-05-21 — claude — `maxPrice` / `minPrice` are now bounds on the
  1e18-scaled out/in execution-price ratio (out-asset denominated in
  in-asset). Added `_executionPrice` helper; `_executeSwap` and `checkUpkeep`
  compare it against the configured bounds. `PriceAboveCeiling` /
  `PriceBelowFloor` selectors unchanged, but the first arg is now
  `executionPrice`, not raw `inPrice`. `_MIN_INTERVAL` lowered from 7 days
  to 1 day.
- 2026-05-21 — claude — switched `StrategyState.status` to `Status` enum
  (was `uint8`) for compile-time safety; wire format unchanged.
- 2026-05-21 — claude — renamed `executeDCA` → `executeStrategy`; ABIs and
  keeper updated in lockstep.
- 2026-05-21 — claude — dropped `_strategyOwners` mapping; ownership is now
  proven statelessly via commitment + `msg.sender == config.owner`.
  `editStrategy` now takes `(oldConfig, newConfig)`; ownership transfer is
  disallowed.
- 2026-05-21 — claude — removed `strategyId` from `StrategyConfig`;
  `editStrategy` / `resumeStrategy` / `pauseStrategy` / `cancelStrategy` /
  `executeStrategy` / `checkUpkeep` now take `strategyId` as an explicit
  first arg.
- 2026-05-21 — claude — added `_activeCommitments` + `DuplicateStrategy`
  error; terminal states (Cancel/Complete) intentionally do not free the
  commitment.
- 2026-05-21 — claude — added auto-COMPLETED transition in
  `_executeSwapCore` + `StrategyCompleted(strategyId, reason)` event.
- 2026-05-21 — claude — initial CLAUDE.md set across DCA system.
