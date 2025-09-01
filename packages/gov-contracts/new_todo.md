## SummerStaking TODO

- **Interfaces**

  - [ ] Add `ISummerStaking` exposing: `stakeWithNewLockup`, `addToStake`, `unstakeFromLockup`,
        `calculateWeightedStake`, `calculatePenalty`, `weightedBalanceOf`, `getUserStake`,
        `getUserStakesCount`, `getBucketDetails`, `getAllBucketInfo`, `getBucketTotalStaked`,
        `updateLockupBucketCap`.
  - [ ] Add `IWrappedStakingToken` (for `depositFor`, `withdrawTo`) and depend on interface instead
        of `WrappedStakingToken`.

- **Penalty (precision + configurability)**

  - [ ] Replace hardcoded 50% with storage `maxPenaltyWad` (default `0.5e18`), bounded to ≤ `1e18`.
  - [ ] Add `setMaxPenaltyWad(uint256)` `onlyGovernor` +
        `MaxPenaltyUpdated(uint256 oldValue, uint256 newValue)` event.
  - [ ] Rewrite `calculatePenalty` using PRBMath UD60x18 to avoid truncation.
  - [ ] Update docstrings to clarify it returns a percentage in WAD.

- **Bucket logic fixes**

  - [ ] In `_initializeDefaultLockupBuckets`, set uncapped buckets to `type(uint256).max` (or
        reinstate special-case logic in `_wouldExceedBucketCap` where `0 = disabled`,
        `max = uncapped`).
  - [ ] Make `_wouldExceedBucketCap` handle `0` (disabled) and `type(uint256).max` (uncapped)
        explicitly.
  - [ ] In `addToStake`, use `existingStake.lockupPeriod` consistently for cap check and bucket
        updates (replace `remainingTime` in `_updateBucketTotalOnAdd`).
  - [ ] Make min lockup values consistent between `getBucketDetails` and `getAllBucketInfo` (pick
        `1 seconds` or `1 days` and use uniformly).

- **Weighted stake formula**

  - [ ] Consider making `WEIGHTED_STAKE_BASE` and `WEIGHTED_STAKE_COEFFICIENT` configurable
        (governor-settable) or at least expose getters.
  - [ ] Keep `_calculateWeightedStake` pure UD60x18; verify no overflows for 4y max.

- **Tests**

  - [ ] Unit tests for `calculateWeightedStake` vs spreadsheet across: 0, 30d, 90d, 180d, 365d, 2y,
        4y (with tolerance).
  - [ ] Tests for staking/adding/unstaking updating `_balances`, `_weightedBalances`, `totalSupply`.
  - [ ] Tests for `earned()` behavior with weighted balances.
  - [ ] Penalty tests: immediate/halfway/end for 1y/2y/4y; partial unstake; zero after expiry;
        respects `maxPenaltyWad`.
  - [ ] Bucket cap tests: disabled bucket (cap 0), uncapped (`type(uint256).max`), and finite caps;
        `addToStake` cap usage.
  - [ ] Getter consistency tests: `getBucketDetails` vs `getAllBucketInfo`.
  - [ ] Governance tests: `setMaxPenaltyWad` access control and bounds; `updateLockupBucketCap`
        emits events.
  - [ ] Fuzz boundary tests around bucket thresholds and max lockup (4y).

- **Docs and events**

  - [ ] Fix docstrings for `calculatePenalty` (percentage vs amount) and clarify bucket semantics
        (cap 0 disabled, max uncapped).
  - [ ] Either remove `LockupBucketAdded` or implement dynamic buckets; currently never emitted.
  - [ ] Add event for penalty config updates (see above).

- **Cleanup**

  - [ ] Remove unused imports: `ProtocolAccessManaged`, `EnumerableMap` (unless needed).
  - [ ] Remove `MAX_PENALTY_PERCENTAGE` constant or wire it to config.
  - [ ] Ensure consistent naming for errors/messages.

- **Build/tooling**

  - [ ] Resolve pragma vs toolchain: change `pragma solidity 0.8.28;` to `0.8.26` (or upgrade
        compiler) to fix linter error.
  - [ ] Run linters/formatters and fix warnings.

- **Security/robustness (nice-to-have)**
  - [ ] Consider `nonReentrant` on external stake/unstake paths.
  - [ ] Re-verify external calls ordering (burn/withdraw/transfer) and `forceApprove` usage.
  - [ ] Add view helpers for frontend (e.g., batched user stake summaries).
