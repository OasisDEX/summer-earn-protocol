# Security Review — DCAStrategyManager

**Date:** 2026-05-26
**Scope:** DCAStrategyManager and all related DCA contracts
**Confidence threshold:** 75

## Files Reviewed

| File | nSLOC |
|------|-------|
| `DCAStrategyManager.sol` | ~300 |
| `ChainlinkOracleUtils.sol` | ~80 |
| `ChainlinkPriceConsumer.sol` | ~25 |
| `EnsoRouterSwapper.sol` | ~40 |
| `HarborCommandConsumer.sol` | ~30 |
| `Permit2Consumer.sol` | ~55 |
| **Total** | **~530** |

---

## Findings

### [85] F-1 — Anyone can create a strategy on behalf of any address

**Contract:** `DCAStrategyManager.createStrategy`
**Agents:** 2
**Confidence:** 85

`createStrategy` is permissionless and never checks `msg.sender == config.owner`. Any caller can register a strategy naming an arbitrary victim as `config.owner`. When the keeper subsequently calls `executeStrategy`, `_pullFunds` pulls `tradeAmount` source-vault shares from the victim via their pre-existing Permit2 sub-allowance — shares the victim granted to `DCAStrategyManager` for their own strategies.

**Attack scenario:**
1. Victim approves `DCAStrategyManager` on Permit2 to enable their own strategies.
2. Attacker calls `createStrategy(config)` with `config.owner = victim`, `config.tradeAmount = victim's entire allowance`, any target vault, shortest valid interval.
3. Keeper executes: victim's source shares are swept, converted via Enso, and target shares delivered back to victim. The victim is not financially harmed by the single trade, but:
   - They cannot stop or pause the strategy (commitment hash proves it's theirs — it isn't).
   - The strategy counts against their `activeCommitments` slot for this config hash.
   - With a carefully chosen config they get a sub-optimal trade executed against their will.

**Fix:**

```diff
 function createStrategy(
     StrategyConfig calldata config
 )
     external
     onlyActiveFleetCommander(config.sourceVault, "source")
     onlyActiveFleetCommander(config.targetVault, "target")
     returns (uint256 strategyId)
 {
+    if (_msgSender() != config.owner) {
+        revert UnauthorizedAccess(0, _msgSender());
+    }
     _validateStrategyConfig(config);
```

---

### [80] F-2 — Chainlink oracle staleness is never validated

**Contracts:** `ChainlinkPriceConsumer._getPrice`, `ChainlinkOracleUtils.convertAmount`
**Agents:** 6
**Confidence:** 80

Both `_getPrice` (`ChainlinkPriceConsumer.sol:31`) and `convertAmount` (`ChainlinkOracleUtils.sol:106–112`) discard the `updatedAt` and `answeredInRound` fields returned by `latestRoundData`. The NatSpec at `ChainlinkPriceConsumer.sol:23` explicitly documents this as intentional and delegates freshness checking to "callers that need it" — but no caller implements such a check.

During a Chainlink feed outage, L2 sequencer downtime, or circuit-breaker event, `latestRoundData` continues to return the last cached price with an arbitrarily old `updatedAt`. The minOut slippage floor and price-bound guards (`maxPrice` / `minPrice`) are then computed from a price that no longer reflects market reality.

**Impact:** Keeper executes strategies at wrong prices; `minOut` is mis-calibrated; price guards do not fire when they should.

**Fix (both call sites):**

```diff
 // ChainlinkPriceConsumer.sol
-    (, int256 raw, , , ) = AggregatorV3Interface(feed).latestRoundData();
+    (, int256 raw, , uint256 updatedAt, ) = AggregatorV3Interface(feed).latestRoundData();
+    if (block.timestamp - updatedAt > MAX_ORACLE_STALENESS) {
+        revert ChainlinkOracleUtils.ChainlinkOracleStalePrice();
+    }
     if (raw <= 0) revert ChainlinkOracleUtils.ChainlinkOraclePriceZero();
```

```diff
 // ChainlinkOracleUtils.sol
-    (, int256 rawIn, , , ) = AggregatorV3Interface(inFeed).latestRoundData();
+    (, int256 rawIn, , uint256 inUpdatedAt, ) = AggregatorV3Interface(inFeed).latestRoundData();
+    if (block.timestamp - inUpdatedAt > MAX_ORACLE_STALENESS) revert ChainlinkOracleStalePrice();
     if (rawIn <= 0) revert ChainlinkOraclePriceZero();

-    (, int256 rawOut, , , ) = AggregatorV3Interface(outFeed).latestRoundData();
+    (, int256 rawOut, , uint256 outUpdatedAt, ) = AggregatorV3Interface(outFeed).latestRoundData();
+    if (block.timestamp - outUpdatedAt > MAX_ORACLE_STALENESS) revert ChainlinkOracleStalePrice();
     if (rawOut <= 0) revert ChainlinkOraclePriceZero();
```

A `MAX_ORACLE_STALENESS` constant of `3600` (1 hour) is a reasonable default for most Chainlink feeds; use the feed's documented heartbeat interval if it differs.

---

### [78] F-3 — `editStrategy` on a terminal strategy frees its commitment hash

**Contract:** `DCAStrategyManager.editStrategy`
**Agents:** 3
**Confidence:** 78

`editStrategy` has no status check. When called on a COMPLETED or CANCELLED strategy it unconditionally executes:

```solidity
// DCAStrategyManager.sol:182
activeCommitments[oldCommitment] = false;
activeCommitments[newCommitment] = true;
strategyCommitments[strategyId] = newCommitment;
```

This frees `oldCommitment`, which the CLAUDE.md invariant documents as permanently locked for terminal states:

> *Terminal states (Cancelled/Completed) do NOT free the entry — the user gets a fresh hash naturally because real edits change at least one field.*

After the edit, a new strategy with the old config hash can be created, bypassing the duplicate-prevention lock.

**Fix:**

```diff
 function editStrategy(
     uint256 strategyId,
     StrategyConfig calldata oldConfig,
     StrategyConfig calldata newConfig
 )
     external
     onlyStrategyOwner(strategyId, oldConfig)
     onlyActiveFleetCommander(newConfig.sourceVault, "source")
     onlyActiveFleetCommander(newConfig.targetVault, "target")
 {
+    StrategyState storage state = _strategyStates[strategyId];
+    if (state.status == Status.CANCELLED || state.status == Status.COMPLETED) {
+        revert StrategyNotActive(strategyId);
+    }
     if (newConfig.owner != oldConfig.owner) {
```

---

### [75] F-4 — `cancelStrategy` allows `COMPLETED → CANCELLED` transition

**Contract:** `DCAStrategyManager.cancelStrategy`
**Agents:** 4
**Confidence:** 75

The `cancelStrategy` guard only blocks a double-cancel:

```solidity
// DCAStrategyManager.sol:238
if (state.status == Status.CANCELLED) {
    revert StrategyNotActive(strategyId);
}
```

A COMPLETED strategy passes this check. The owner can then emit a contradictory `StrategyCancelled` event on a strategy that already emitted `StrategyCompleted`. Off-chain indexers (subgraph, keeper, app) may handle the resulting ambiguous state incorrectly.

**Fix:**

```diff
-    if (state.status == Status.CANCELLED) {
+    if (state.status == Status.CANCELLED || state.status == Status.COMPLETED) {
         revert StrategyNotActive(strategyId);
     }
```

---

### [75] F-5 — `slippageBps = 10000` accepted, disabling the slippage floor

**Contract:** `DCAStrategyManager._executeStrategy`
**Agents:** 3
**Confidence:** 75

`_validateStrategyConfig` accepts `slippageBps` up to `10000` (100 BPS, where BPS = basis points of 100%). At `slippageBps = 10000`, `subtractBps` computes:

```
minOut = expectedOutShares * (10000 - 10000) / 10000 = 0
```

`swappedAmount < 0` is always false for a `uint256`, so the `SwapOutputBelowMinOut` revert never fires. The swap has no floor: a keeper can route source shares through any path — including one that returns dust — without the transaction reverting.

**Note:** In the current system, strategies are created by their own owner, so a user who intentionally sets `slippageBps = 10000` is harming only themselves. However if F-1 is not fixed (permissionless creation), an attacker could use this in combination to force zero-slippage trades on victims.

**Fix:**

```diff
 // In _validateStrategyConfig
-    if (!BPS.wrap(config.slippageBps).isBpsInRange()) {
+    if (config.slippageBps >= _MAX_SLIPPAGE_BPS) {
         revert InvalidSlippage(config.slippageBps);
     }
```

Where `_MAX_SLIPPAGE_BPS` is a constant set to a protocol-appropriate maximum (e.g., `3000` for 30%).

---

## Leads

The following items were identified but did not reach the confidence threshold for a finding. They are included for developer awareness.

| ID | Location | Summary | Confidence |
|----|----------|---------|------------|
| L-1 | `ChainlinkOracleUtils.convertAmount:120` | `inAmount * inPrice.value` and `outPrice.value * inNorm` are plain multiplications outside `mulDiv`; overflow is possible for very large amounts with high-decimal assets | 65 |
| L-2 | `DCAStrategyManager.editStrategy:189` | `nextTriggerAt = lastScheduledAt + newInterval`; if `lastScheduledAt + newInterval < block.timestamp`, the trigger is already in the past and keeper can execute immediately after edit | 65 |
| L-3 | `DCAStrategyManager.executeStrategy` | `checkUpkeep` and `executeStrategy` read Chainlink prices in separate transactions; price can move into or out of range between the two calls | 60 |
| L-4 | `HarborCommandConsumer.onlyActiveFleetCommander` | Vault registry check happens at create/edit time only; a vault deregistered from HarborCommand after strategy creation remains executable | 55 |
| L-5 | `EnsoRouterSwapper._ensoSwap` | `ensoData` is fully keeper-provided and forwarded verbatim; only the `minOut` balance-delta floor limits what the keeper can direct with the approved source shares | 55 |
| L-6 | Chain: F-1 + F-5 | Permissionless creation with `slippageBps = 10000` enables zero-slippage forced trades on any address that has a Permit2 sub-allowance set | 70 |

---

## Findings Summary

| ID | Title | Confidence | Severity |
|----|-------|-----------|---------|
| F-1 | Anyone can create a strategy on behalf of any address | 85 | High |
| F-2 | Chainlink oracle staleness not validated | 80 | Medium |
| F-3 | `editStrategy` on terminal strategy frees commitment hash | 78 | Medium |
| F-4 | `cancelStrategy` allows COMPLETED → CANCELLED transition | 75 | Low |
| F-5 | `slippageBps = 10000` disables slippage floor | 75 | Low |

---

*Report generated by the [Pashov Audit Group solidity-auditor skill](https://github.com/pashov/skills). Findings represent security-relevant observations at the time of review. Confirm each fix against the full test suite before deployment.*
