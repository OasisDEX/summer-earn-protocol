---
description: Privileged governance, keeper, curator and guardian operations in the Summer.fi Earn Protocol, the timelock model that gates governance, and the pause/unpause surfaces.
---

# Privileged Operations

This page describes what privileged actors can do, how governance actions are time-delayed, and which contracts can be paused. For the role-to-modifier mapping see [Roles and Access Control](roles-and-access-control.md).

## Governance and the timelock

On-chain governance executes through an OpenZeppelin `TimelockController`. Two timelock contracts exist:

- [`SummerTimelockController`](../governance/reference/contracts/summer-timelock-controller.md) — the protocol governance timelock, used by `SummerGovernor`.
- [`RwaTimelock`](../governance/reference/contracts/rwa-timelock.md) — a thin wrapper over `TimelockController` for the institutional RWA stack.

### SummerTimelockController

`SummerTimelockController` extends `TimelockController` and adds guardian-aware cancellation plus special handling for guardian-expiry operations. The standard timelock roles apply:

- **`PROPOSER_ROLE`** — may `schedule` / `scheduleBatch` operations. Both are overridden to set `onlyRole(PROPOSER_ROLE)`.
- **`EXECUTOR_ROLE`** — may execute operations once the delay has elapsed.
- **`CANCELLER_ROLE`** — may cancel scheduled operations, subject to the rules below.
- **`DEFAULT_ADMIN_ROLE`** — administers the timelock's own roles.

Cancellation rules enforced by the overridden `cancel(bytes32 id)`:

1. **Guardian-expiry proposals can only be cancelled by governors.** When `schedule`/`scheduleBatch` sees a payload whose selector is `setGuardianExpiration`, it flags the operation id as a guardian-expiry operation. Those ids can only be cancelled by an account with `GOVERNOR_ROLE`. This prevents a guardian from blocking its own scheduled expiry.
2. **Governors with `CANCELLER_ROLE` can cancel any proposal** (`_isGovernorWithCancelRole` requires both `CANCELLER_ROLE` here and `GOVERNOR_ROLE` on the access manager).
3. **Active guardians with `CANCELLER_ROLE` can cancel any non-expiry proposal** (`_isActiveGuardianWithCancelRole` requires `CANCELLER_ROLE` and `accessManager.isActiveGuardian`).

### minDelay is governable

`minDelay` is a `TimelockController` parameter, not a compile-time constant. It can be changed through the timelock itself (the standard `updateDelay` path executed via a scheduled operation), so the enforced review window is a governance-controlled value. Reviewers should read the current `minDelay` from the live timelock rather than assuming a fixed value.

### RwaTimelock

`RwaTimelock` is a behaviour-preserving wrapper over `TimelockController` (no logic overridden) used for the institutional RWA stack. Per its NatSpec, two instances are deployed per institution from the same code:

- A **governor timelock** granted `GOVERNOR_ROLE` and made the institution's sole governor; every governor-gated action (HarborCommand enlist/decommission, RoundsVault emergency controls, role grants) flows through it.
- A **curator timelock** granted the per-fleet `CURATOR_ROLE` on each FleetCommander.

Delay semantics: the timelock is always present. With `minDelay == 0` an operation can be scheduled and executed in the same block (immediate execution); with `minDelay > 0` a mandatory review window applies. The two instances are configured independently per institution. Executors are expected to be `address(0)` (open execution — anyone may execute a ready operation); proposers are the institution's governor set. Setting `admin = address(0)` yields a fully self-administered timelock (recommended) so role changes must themselves go through the timelock.

## Governor operations

The governor is the broadest authority. Beyond granting/revoking every role (see the matrix), representative governor-gated state changes confirmed in code include:

- **Fleet lifecycle**: add Arks, set fleet token transferability, force-rebalance, set tip rate, set minimum pause time (`FleetCommander`, `FleetCommanderConfigProvider*`); enlist/decommission Fleets (`HarborCommand`).
- **Protocol wiring**: set treasury, tipjar, raft, rewards-manager factory (`ConfigurationManager*`).
- **Cross-chain**: register/remove bridge adapters, recover router assets, unpause the router (`BridgeRouter`); register relationships/executors/peers, set router and default gas limits (`CrossChainRegistry`); endpoint mapping, read DVN/library configuration, supported assets, manual recovery (`LayerZeroAdapter`, `StargateAdapter`).
- **Tokenomics**: decay rate, decay-free window, decay factor (`SummerToken`); staking/vesting administration and rescues (`StakedSummerToken`, `SummerStaking`, `SummerVestingWalletsEscrow`); rewards duration / reward-token management / redeemer roots (`StakingRewardsManagerBase`, `SummerRewardsRedeemer`).
- **Ark emergency/config**: emergency sweeps, oracle/slippage configuration, emergency-clear of pending deposits (`BaseSuperstateArk`, `BasePendleArk`, `WisdomTreeArk`, and others).

## Keeper operations

Keepers (or super-keepers) perform routine maintenance, none of which can move user funds to an arbitrary destination:

- **Rebalance** a Fleet between Arks, constrained by curator-set per-Ark inflow/outflow limits, max deposit % of TVL, and minimum buffer (`FleetCommander.rebalance`). `forceRebalance` bypasses some constraints but is **governor-gated**, not keeper-gated.
- **Async/custodial Ark lifecycle**: request and claim withdrawals, swap-withdraw, sweep across the async Arks (Origin, Maple, Syrup, Aera, Arm, WisdomTree, Superstate, Fluid, Upshift, …).
- **Rounds vault**: advance, retry and settle rounds (`RoundsVaultBase`).
- **TipJar**: shake / shake-multiple tip streams; `shakeAll` is guardian-gated.
- **Intents**: create/settle intents and manage solver escrows (`IntentHandler`).

The super-keeper additionally has the privileged Raft harvest path (`Raft._harvest`, `onlySuperKeeper`).

## Curator operations

Curators tune a single Fleet's risk envelope (deposit cap, minimum buffer, per-Ark deposit %, rebalance inflow/outflow, max rebalance operations, rebalance cooldown, staking-rewards-manager) and can remove an Ark from a Fleet — but cannot add Arks or move funds. Ark-level curation (slippage, router/swap-pool whitelists, oracle/auction parameters) is also curator-gated on the relevant Arks. See the matrix for the exact functions.

## Guardian operations

The guardian is a time-bounded emergency backstop (`MIN_GUARDIAN_EXPIRY` = 7 days, `MAX_GUARDIAN_EXPIRY` = 180 days). Guardian powers confirmed in code:

- **Pause** Fleets and the bridge router (shared with governor — see below).
- **Emergency caps**: set a fleet/ark deposit cap to zero (`FleetCommanderConfigProviderDao`).
- **TipJar emergency stop**: `shakeAll`.
- **Staking**: pause and remove staking module (`StakedSummerToken`).
- **Governance**: cancel proposals and propose below the normal threshold, gated on `isActiveGuardian` (`SummerGovernor`); cancel non-expiry timelock operations (`SummerTimelockController`).

The expiry mechanism is deliberate: `setGuardianExpiration` (governor-only) requires the new expiry to be between 7 and 180 days out, so a guardian can neither be removed instantly (protecting against a malicious proposal to disarm the backstop) nor persist indefinitely (protecting against a malicious guardian). Guardian-expiry timelock operations can only be cancelled by governors.

## Pause surfaces

| Surface | Pause authority | Unpause authority | Extra constraint |
| --- | --- | --- | --- |
| `FleetCommander` / `FleetCommanderDao` | `onlyGuardianOrGovernor` | `onlyGuardianOrGovernor` | Unpause blocked until `pauseStartTime + minimumPauseTime`; `minimumPauseTime >= MINIMUM_PAUSE_TIME_SECONDS` (2 days) |
| `FleetCommanderWhitelist` | `onlyGovernor` (`pause`) | `onlyGovernor` (`unpause`) | Same minimum-pause-time floor via `FleetCommanderPausable` |
| `BridgeRouter` | `onlyGuardianOrGovernor` | `onlyGovernor` | Unpause is governor-only |
| `TipJar` | `onlyGovernor` (`pause`); `onlyGuardian` (`shakeAll` emergency) | — | — |
| `StakedSummerToken` | `onlyGuardian` (`pause`) | — | — |

The minimum-pause-time floor comes from [`FleetCommanderPausable`](../contracts/core/reference/contracts/fleet-commander-pausable.md), which overrides OpenZeppelin `Pausable` so that `_unpause()` reverts with `FleetCommanderPausableMinimumPauseTimeNotElapsed` until the minimum pause window has elapsed. `MINIMUM_PAUSE_TIME_SECONDS` is a hard floor of 2 days and `setMinimumPauseTime` (governor-gated) cannot set it lower. This guarantees that once a Fleet is paused it stays paused long enough for governance to respond, even if a guardian is compromised and would otherwise unpause immediately.

> TODO (human input): If a separate operational runbook exists describing the human/multisig procedure for invoking pause and recovering, link it here. Not derivable from source.
