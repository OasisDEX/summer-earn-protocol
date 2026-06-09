# DCAStrategyManager — AI Security Audit

> **Type:** AI-conducted adversarial security audit. Companion to
> [`DCAStrategyManager.product.md`](./DCAStrategyManager.product.md) (product spec)
> and [`DCAStrategyManager.technical.md`](./DCAStrategyManager.technical.md)
> (technical/integration reference).
> **Date:** 2026-06-03
> **Method:** two independent frontier models reviewed the contract adversarially
> via the `/second-opinion` skill — Google **`gemini-3.1-pro-preview`** (security
> extension) and OpenAI **`gpt-5.5`** (reasoning `xhigh`, structured output) —
> followed by a Claude-led source verification of each finding against the
> FleetCommander vault.
> **Scope:** `DCAStrategyManager.sol` plus `EnsoRouterSwapper`, `Permit2Consumer`,
> `HarborCommandConsumer`, `ChainlinkOracleUtils`, and the
> interface/events/errors.
>
> ⚠️ **These are model-generated findings, hand-verified against the source. Treat
> them as reviewed leads — not a substitute for a professional human audit.**

## Status of the prior review

An earlier external review (2026-05-26, Pashov `solidity-auditor` skill) raised
five findings F-1…F-5 (permissionless creation, oracle staleness, terminal-edit
freeing the commitment, `COMPLETED → CANCELLED`, 100% slippage). **All five are
remediated in the current source** and are intentionally *not* repeated here. This
document carries only the **fresh** findings from the 2026-06-03 AI audit.

## Findings summary

| ID | Title | Severity | Status |
|----|-------|----------|--------|
| C-1 | Keeper can route swap surplus to itself (`minOut` is not a floor vs. the keeper) | High | **Risk accepted — keeper trusted** |
| C-2 | `minOut` can round to zero for tiny expected-share counts | Low (was Med) | Open — defense-in-depth |
| C-3 | `checkUpkeep` does not mirror `executeStrategy` preconditions | Medium | Open |
| X-1 | Permit2 fallback ignores allowance expiration | Low | Open |
| G-1 | Execution schedule drifts off the hour alignment | Info | Open |

---

## C-1 — Keeper can route swap surplus to itself · HIGH · **Risk accepted (keeper trusted)**

*Both models — Codex confidence 0.86, Gemini confidence 1.0.*

**Finding.** `_executeSwap` (`DCAStrategyManager.sol:771-786`) approves
`tradeAmount` source-vault shares to the Enso router and forwards opaque,
keeper-supplied `ensoData`. The only post-swap check is that the manager's
*target-share balance delta ≥ minOut*; nothing constrains where the route sends
the remaining value. A malicious or compromised keeper can route the full pulled
amount, deliver exactly `minOut` target shares to the manager (which are then
forwarded to the owner), and divert the surplus to itself — on every trade.

- `minOut = expectedOutShares × (1 − slippageBps)`. With the 50% cap, up to ~50%
  of expected output is skimmable while still passing; even a tight `slippageBps`
  is a per-trade skim ceiling, not a one-off MEV risk.
- The 24h oracle-staleness tolerance widens the gap between `minOut` and the live
  market price, so the capturable surplus can exceed the user's intended slippage.

**Verification.** Confirmed against the source and **independent of vault
internals** (see [Verification against FleetCommander](#verification-against-fleetcommander)).
The manager never constrains the Enso route's output recipient, so this holds for
any ERC4626 source/target.

**Risk acceptance — the keeper is trusted.** The keeper is a permissioned role
(`KEEPER_ROLE` / `SUPER_KEEPER_ROLE`, granted by protocol governance) operated by
the protocol. The DCA threat model already trusts the keeper for execution timing
and route selection. The protocol therefore **accepts this risk**: a malicious
keeper is out of scope of the current trust model, and `minOut` is treated as a
slippage bound for an *honest* keeper, not as a defense against the keeper itself.

> **Condition on this acceptance:** it holds only while the keeper set is trusted
> and permissioned. **If keepers ever become permissionless or third-party, this
> finding reverts to High and must be mitigated** — e.g. a constrained swap
> wrapper that hard-codes the output recipient to `address(this)` (the manager
> supplies `tokenIn` / `tokenOut` / `amount` / `minOut`), or decoding/whitelisting
> the Enso route and rejecting any non-manager output recipient, then forwarding
> the full measured output to the owner.

---

## C-2 — `minOut` can round to zero for tiny expected-share counts · LOW (defense-in-depth)

*Codex confidence 0.70; Gemini detail.*

**Finding.** The execution guards reject `expectedOutShares == 0` but not the case
where `subtractBps` floors a small positive value to `minOut = 0` (e.g.
`expectedOutShares == 1, slippageBps > 0`). With `minOut == 0`, a route returning
zero target shares passes the floor (`swappedAmount < 0` is never true).

**Verification — amplifying exploit largely mitigated for FleetCommander.** The
amplifying attack (inflate the target vault's share price until
`previewDeposit → 1`) does **not** work via a normal donation:
`FleetCommander.totalAssets()` sums Ark positions, not the vault's own balance, so
a direct ERC20 transfer to the vault is uncounted; plus OZ ERC4626's default
`+1/+1` virtual offset. Forcing `previewDeposit → 1` would require donating on the
order of total TVL (only the buffer Ark is a theoretical vector, and only at
near-zero TVL). See [Verification against FleetCommander](#verification-against-fleetcommander).

**Recommendation (defense-in-depth).** Independent of exploitability, add
`require(minOut > 0)` after applying slippage, consider rounding the floor up,
and/or enforce a minimum trade size. Cheap protection, chiefly for new / low-TVL
target vaults.

---

## C-3 — `checkUpkeep` does not mirror `executeStrategy` preconditions · MEDIUM · Open

*Codex confidence 0.90; Gemini LOW on the `endDate` sub-case.*

**Finding.** `checkUpkeep` (`DCAStrategyManager.sol:418-458`) checks
hash/status/timing and reads Chainlink only when price bounds are set. It does
**not** mirror `executeStrategy`'s active-vault modifiers, its unconditional
oracle/`minOut` computation, the `ZeroExpectedOutShares` path, or Permit2
allowance/expiration & owner-balance state. It also returns `false` once `endDate`
passes.

**Impact.**
- *False positives → keeper gas-griefing.* A self-owned strategy with active
  vaults, no price bounds, bogus/stale feed addresses, and no Permit2 allowance
  returns `upkeepNeeded = true`, but `executeStrategy` then reverts in the oracle
  call or the Permit2 pull. The same mismatch appears after a vault is
  deregistered post-creation.
- *Stranded `ACTIVE`.* A strategy that reaches `endDate` without ever hitting an
  execution window can never reach `COMPLETED` via a keeper that only trusts
  `checkUpkeep` (the auto-complete path is unreachable), leaving it `ACTIVE`-but-
  dead until the owner cancels.

**Recommendation.** Mirror the execution preconditions in `checkUpkeep` (Harbor
status, feed freshness, expected/min output, Permit2 allowance + expiration) and
surface an `endDate` cleanup signal; or explicitly document `checkUpkeep` as a
partial readiness hint and require keepers to simulate `executeStrategy`.

---

## X-1 — Permit2 fallback ignores allowance expiration · LOW · Open

*Codex confidence 0.78.*

**Finding.** `Permit2Consumer._applyPermit2Allowance` (`lines 140-146`) catches a
failed `PERMIT2.permit` and then accepts a pre-existing allowance checking only
`amount`, discarding the returned `expiration`. The create-time
`_requirePermit2CoversStrategy` validates the *signed* expiration, but if the
in-tx permit fell into the catch path against an older allowance, that allowance's
expiration may be earlier than `endDate`. Later keeper pulls then revert with
Permit2 `AllowanceExpired`, stranding the strategy mid-life.

**Recommendation.** In the catch path read `(amount, expiration, nonce)` and
require both `amount ≥ signed amount` **and** `expiration ≥ signed expiration` (or
`≥ endDate`); ideally suppress only the specific already-applied-nonce race this
path was built for.

---

## G-1 — Execution schedule drifts off hour alignment · INFO · Open

*Gemini.*

**Finding.** Creation hour-aligns `nextTriggerAt`, but each execution sets
`nextTriggerAt = block.timestamp + interval`, so the slot drifts forward by the
keeper's mining delay every trade, eventually defeating the alignment.

**Recommendation (optional).** Anchor to the previous trigger:
`nextTriggerAt = state.nextTriggerAt + interval`. Trade-off: a late keeper can then
bunch catch-up executions.

---

## Verification against FleetCommander

C-1 and C-2 both hinge on the source/target vaults' ERC4626 internals, so each was
traced against the actual vault.

**What FleetCommander is:**
- Inherits **OpenZeppelin's standard `ERC4626`** (`FleetCommander.sol:13,29,49`,
  `constructor … ERC4626(IERC20(params.asset))`) — appreciating shares, standard
  OZ conversion formulas.
- **Does not override `_decimalsOffset()`** → OZ default `0` → the conversion math
  carries OZ's built-in `+1` virtual asset / `+1` virtual share dampener:
  `shares = assets·(totalSupply+1)/(totalAssets+1)` and the inverse.
- **Overrides `totalAssets()`** (`FleetCommander.sol:359`) →
  `_totalAssets(config.bufferArk)` → `FleetCommanderCacheLib.totalAssets` →
  `sumTotalAssets(getAllArks(...))` = the sum of each **Ark's** position plus the
  buffer Ark. **It does not read the vault's own `asset.balanceOf(this)`.**

**C-1 — CONFIRMED, independent of vault internals.** The manager approves
`tradeAmount` source shares to Enso and verifies only the *target-share balance
delta ≥ minOut*; it never constrains the route's output recipient. A
malicious/compromised keeper can deliver exactly `minOut` and divert the rest.
This holds for any ERC4626 vault. Severity gate: the keeper is permissioned, so
this is an insider/compromise threat — hence the risk acceptance above.

**C-2 — inflation amplifier LARGELY MITIGATED for FleetCommander.** The classic
"donate tokens to the vault to inflate the share price" move does **not** work: a
direct ERC20 transfer to the FleetCommander address is *uncounted* because
`totalAssets()` reads Ark positions, not the vault's own balance. Add the OZ
`+1/+1` virtual offset, and forcing `previewDeposit(expectedOutAssets) → 1` would
require share price (assets/share) to exceed a whole trade's `expectedOutAssets`,
i.e. a donation on the order of total TVL — economically irrelevant for any
established vault. The only theoretical donation vector is into the **buffer Ark**
(whose `totalAssets()` reads its own balance), and even that is TVL-gated; it could
only bite a brand-new, near-empty target vault. The `minOut == 0` guard gap (C-2)
remains a cheap defense-in-depth fix regardless.

---

## What the audit did NOT find broken
- The stateless commitment ownership model is sound; neither model found an
  unprivileged path to pull another user's shares (the original F-1 stays fixed).
- Permit2 sub-allowance sizing and Chainlink decimal normalisation are correct.

## Model verdicts
- **Codex (`gpt-5.5`):** "not safe under the stated adversarial keeper and griefing
  assumptions"; commitment model sound; root issue is over-trusting the keeper's
  Enso calldata. Overall confidence 0.82. *(Resolved here via the C-1 risk
  acceptance — the keeper is trusted by design.)*
- **Gemini (`gemini-3.1-pro-preview`):** 9.5/10 architecture; the share-denominated
  `minOut` against a manipulable spot rate flagged as must-fix. *(Mitigated for
  FleetCommander per verification; C-1 risk-accepted.)*

## Open items (priority)
1. **C-3** — align `checkUpkeep` with execution (or document it as a partial hint).
2. **X-1** — Permit2 catch-path expiration check.
3. **C-2** — `require(minOut > 0)` defense-in-depth.
4. **G-1** — optional rigid scheduling.

> C-1 is **risk-accepted** under the trusted/permissioned-keeper model. Revisit if
> keepers ever become permissionless.

---

> Provenance: `/second-opinion` skill (Trail of Bits) + Claude-led source
> verification. Confirm each item against the source and the test suite before
> acting.
