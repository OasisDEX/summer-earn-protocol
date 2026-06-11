---
description: The complete role model of the Summer.fi Earn Protocol — every role defined in ProtocolAccessManager / V2, what it gates, and the modifier and contract that enforce it.
---

# Roles and Access Control

All protocol authority is defined in [`ProtocolAccessManager`](../contracts/access/reference/contracts/protocol-access-manager.md) and its institutional extension [`ProtocolAccessManagerV2`](../contracts/access/reference/contracts/protocol-access-manager-v2.md). Consumers inherit [`ProtocolAccessManaged`](../contracts/access/reference/contracts/protocol-access-managed.md) (or [`ProtocolAccessManagedV2`](../contracts/access/reference/contracts/protocol-access-managed-v2.md)) and gate functions with the modifiers those base contracts expose.

## Role categories

Roles come in two shapes:

- **Global roles** — a single `bytes32` constant checked protocol-wide (e.g. `GOVERNOR_ROLE`, `SUPER_KEEPER_ROLE`, `GUARDIAN_ROLE`).
- **Contract-scoped roles** — generated per target contract via `generateRole(roleName, targetContract) = keccak256(abi.encodePacked(roleName, targetContract))`. The same logical role (e.g. Keeper) is therefore a distinct grant on every Fleet. The scoped role names live in the `ContractSpecificRoles` enum: `CURATOR_ROLE`, `KEEPER_ROLE`, `COMMANDER_ROLE`, and (V2) `OPERATOR_ROLE`.

Direct `grantRole`/`revokeRole` are disabled by [`LimitedAccessControl`](../contracts/access/reference/contracts/limited-access-control.md); every grant goes through a governor-gated wrapper on the manager. `renounceRole` remains enabled so an account can drop its own role.

## Confirmed role list

The following roles are defined as constants in code (`ProtocolAccessManager` / `ProtocolAccessManagerV2`) or as `ContractSpecificRoles` enum members:

| Role | Identifier source | Scope |
| --- | --- | --- |
| `GOVERNOR_ROLE` | `ProtocolAccessManager` constant | Global |
| `SUPER_KEEPER_ROLE` | `ProtocolAccessManager` constant | Global |
| `GUARDIAN_ROLE` | `ProtocolAccessManager` constant | Global, time-bounded |
| `DECAY_CONTROLLER_ROLE` | `ProtocolAccessManager` constant | Global |
| `ADMIRALS_QUARTERS_ROLE` | `ProtocolAccessManager` constant | Global |
| `FOUNDATION_ROLE` | `ProtocolAccessManager` constant | Global |
| `CURATOR_ROLE` | `ContractSpecificRoles` enum | Per Fleet |
| `KEEPER_ROLE` | `ContractSpecificRoles` enum | Per Fleet/contract |
| `COMMANDER_ROLE` | `ContractSpecificRoles` enum | Per Ark |
| `OPERATOR_ROLE` (V2) | `ContractSpecificRoles` enum | Per contract |
| `WHITELIST_MANAGER_ROLE` (V2) | `ProtocolAccessManagerV2` constant | Global |

The OpenZeppelin `TimelockController` roles `PROPOSER_ROLE`, `EXECUTOR_ROLE`, `CANCELLER_ROLE` and `DEFAULT_ADMIN_ROLE` also exist on the timelock contracts; they are covered under [Privileged Operations](privileged-operations.md).

> TODO (human input): Document **who holds each role in production** on each chain — which addresses are multisigs, which are the governance timelock, which are EOAs/keeper bots, and the guardian set with their expiry timestamps. This is operational configuration resolved against the live `ProtocolAccessManager` and the deployment manifests in `packages/deployment/deployments/`, not something encoded in source.

## Roles matrix

Each row lists the enforcing modifier, the role(s) it checks, and representative privileged functions confirmed in `packages/*/src`. The matrix is representative of the categories of power each role holds; it is not an exhaustive enumeration of every guarded function.

### Governor — `onlyGovernor`

The highest-privilege role. Checked by `_revertIfNotGovernor` against the global `GOVERNOR_ROLE`. Governor is the only role that can grant or revoke any other role.

| What it can do | Enforcing contracts (modifier `onlyGovernor`) |
| --- | --- |
| Grant/revoke every other role (governor, super-keeper, guardian, curator, keeper, commander, decay-controller, admirals-quarters, foundation, operator, whitelist-manager) | `ProtocolAccessManager`, `ProtocolAccessManagerV2` |
| Set guardian expiry, grant/revoke admirals-quarters role (via `onlyRole(GOVERNOR_ROLE)`) | `ProtocolAccessManager` |
| Add/remove Arks, set fleet token transferability, force-rebalance, set tip rate, set minimum pause time | `FleetCommander`, `FleetCommanderConfigProvider(Dao/Whitelist)` |
| Enlist/decommission Fleets | `HarborCommand` |
| Configure protocol singletons (treasury, tipjar, raft, rewards-manager factory) | `ConfigurationManager`(`Whitelist`) |
| Register/remove bridge adapters, unpause and recover assets on the router | `BridgeRouter` |
| Register relationships/executors/peers, set router & gas limits | `CrossChainRegistry` |
| Configure adapters (endpoint mapping, read DVNs/libraries, supported assets, manual recovery) | `LayerZeroAdapter`, `StargateAdapter` |
| Decay/tokenomics parameters (decay rate, decay-free window, decay factor) | `SummerToken` |
| Staking & vesting admin (staking modules, lockup caps, penalty toggle, rescue, vesting factory management) | `StakedSummerToken`, `SummerStaking`, `SummerVestingWalletsEscrow` |
| Rewards admin (reward duration, remove reward token, rescue, redeemer roots / emergency withdraw) | `StakingRewardsManagerBase`, `SummerRewardsRedeemer` |
| Ark emergency / config (emergency sweep, oracle/slippage config, emergency-clear pending deposits) | `BaseSuperstateArk`, `BasePendleArk`, `WisdomTreeArk`, others |

### Super Keeper — `onlySuperKeeper`

Global elevated keeper. Checked by `_revertIfNotSuperKeeper` against `SUPER_KEEPER_ROLE`. Note that the `onlyKeeper` modifier *also* accepts a super-keeper, so a super-keeper can perform any keeper action on any contract.

| What it can do | Enforcing contracts (modifier `onlySuperKeeper`) |
| --- | --- |
| Privileged harvest path on the Raft | `Raft` (`_harvest`) |

### Keeper — `onlyKeeper` (Keeper **or** Super Keeper)

Contract-scoped routine maintenance. Checked by `_revertIfNotKeeper`, which passes if the caller holds the per-contract `KEEPER_ROLE` (`generateRole(KEEPER_ROLE, address(this))`) **or** the global `SUPER_KEEPER_ROLE`.

| What it can do | Enforcing contracts (modifier `onlyKeeper`) |
| --- | --- |
| Rebalance a Fleet (move assets between Arks within curator-set limits) | `FleetCommander`(`Dao`/`Whitelist`) |
| Request/claim withdrawals, swap-withdraw, sweep on async/custodial Arks | Many Arks (`AeraArk`, `ArmArk`, `BaseSuperstateArk`, `Origin*Ark`, `Maple*Ark`, `Syrup*Ark`, `WisdomTreeArk`, `FluidLiteArk`, `UpshiftArk`, …) |
| Advance rounds, retry/settle rounds | `RoundsVaultBase` |
| Shake / shake-multiple tip streams | `TipJar` |
| Whitelist the Merkl operator on an Ark | `Ark` |
| Intent operations (create/settle intents, manage solver escrows, withdraw) | `IntentHandler`, `IntentBondFactory` |

### Curator — `onlyCurator(fleetAddress)`

Per-Fleet risk manager. Checked by `_revertIfNotCurator`, which requires a non-zero fleet address and the per-fleet `CURATOR_ROLE`. A curator tunes a single Fleet's risk envelope but cannot add or remove Arks (that is governor-gated).

| What it can do | Enforcing contracts (modifier `onlyCurator`) |
| --- | --- |
| Set fleet deposit cap, minimum buffer balance, max rebalance operations | `FleetCommanderConfigProvider`(`Dao`/`Whitelist`) |
| Set per-Ark max deposit % of TVL, max rebalance inflow/outflow | `FleetCommanderConfigProvider`(`Dao`/`Whitelist`) |
| Remove an Ark from a Fleet, update the staking rewards manager | `FleetCommanderConfigProvider`(`Dao`/`Whitelist`) |
| Update rebalance cooldown | `FleetCommander` |
| Ark-level curation (slippage, router whitelist, swap-pool whitelist, oracle config, auction params) | `ArkWithSwap`, `BenjiArk`, `PendlePtOracleArk`, `Raft` |

### Guardian — `onlyGuardian`

Time-bounded emergency role. Checked by `_revertIfNotGuardian` against `GUARDIAN_ROLE`. Guardians have an expiry (`MIN_GUARDIAN_EXPIRY` = 7 days, `MAX_GUARDIAN_EXPIRY` = 180 days); `isActiveGuardian` requires both the role and a non-expired timestamp. Some surfaces (e.g. the governor / timelock) check `isActiveGuardian`, while the bare `onlyGuardian` modifier checks role membership only.

| What it can do | Enforcing contract / check |
| --- | --- |
| Emergency stop on the TipJar (shake-all) | `TipJar.shakeAll` (`onlyGuardian`) |
| Pause/stop on staking, remove staking module | `StakedSummerToken` (`onlyGuardian`) |
| Set a fleet/ark deposit cap to zero (emergency cap) | `FleetCommanderConfigProviderDao` (`onlyGuardian`) |
| Cancel governance proposals and propose below threshold (via active-guardian check) | `SummerGovernor` (`isActiveGuardian`) |
| Cancel timelock operations (active guardian with `CANCELLER_ROLE`), except guardian-expiry proposals | `SummerTimelockController` |

### Guardian or Governor — `onlyGuardianOrGovernor`

Shared pause authority. Checked by `_revertIfNotGuardianOrGovernor` (passes for `GUARDIAN_ROLE` **or** `GOVERNOR_ROLE`).

| What it can do | Enforcing contracts (modifier `onlyGuardianOrGovernor`) |
| --- | --- |
| Pause a Fleet | `FleetCommander`(`Dao`/`Whitelist`).`pause` |
| Unpause a Fleet (subject to minimum-pause-time) | `FleetCommander`(`Dao`).`unpause` |
| Pause the bridge router | `BridgeRouter.pause` |

> Note the asymmetry on the bridge: `BridgeRouter.pause` is guardian-or-governor, but `BridgeRouter.unpause` is **governor-only** (`onlyGovernor`). On the Fleet, both pause and unpause are guardian-or-governor, but unpause additionally enforces the 2-day minimum pause time. See [Privileged Operations](privileged-operations.md#pause-surfaces).

### Decay Controller — `onlyDecayController`

Manages voting-power decay. Checked by `_revertIfNotDecayController` against `DECAY_CONTROLLER_ROLE`.

| What it can do | Enforcing contracts (modifier `onlyDecayController`) |
| --- | --- |
| Set the decay function on the token | `SummerToken.setDecayFunction` |
| Update the smoothed decay factor | `GovernanceRewardsManager.updateSmoothedDecayFactor` |

### Foundation — `onlyFoundation`

Manages vesting wallets. Checked by `_revertIfNotFoundation` against `FOUNDATION_ROLE()`.

| What it can do | Enforcing contracts (modifier `onlyFoundation`) |
| --- | --- |
| Add/mark vesting goals, recall unvested tokens, create vesting wallets | `SummerVestingWallet`(`V2`), `SummerVestingWalletFactory` |

### Admirals Quarters — `ADMIRALS_QUARTERS_ROLE`

Bundler role for the Admirals Quarters contract. Checked via `hasAdmiralsQuartersRole`. Per the NatSpec, withdrawn tokens are sent straight to the user's wallet, limiting blast radius if the role is compromised.

| What it can do | Enforcing check |
| --- | --- |
| Unstake and withdraw assets from Fleets on behalf of users | `FleetCommanderRewardsManager.unstakeAndWithdrawOnBehalfOf` (`hasAdmiralsQuartersRole`) |

### Operator (V2) — `onlyOperator`

Per-contract bundler/proxy bypass. Defined in [`ProtocolAccessManagedV2`](../contracts/access/reference/contracts/protocol-access-managed-v2.md); checked by `_revertIfNotOperator` against `generateRole(OPERATOR_ROLE, address(this))`. Lets whitelisted bundlers (Admirals Quarters Whitelist, RoundsVault input/output) bypass a Fleet's user-side whitelist gateway when invoking it.

### Whitelist Manager (V2) — `onlyRole(WHITELIST_MANAGER_ROLE)`

Manages the per-context whitelist used by institutional Fleet variants. Defined in [`ProtocolAccessManagerV2`](../contracts/access/reference/contracts/protocol-access-manager-v2.md).

| What it can do | Enforcing contract |
| --- | --- |
| Set/clear whitelist entries (`setWhitelisted`, `setWhitelistedBatch` — capped at `MAX_WHITELIST_BATCH_SIZE` = 200) | `ProtocolAccessManagerV2` |
| Open a context's whitelist globally (`setWhitelistOpen`) | `ProtocolAccessManagerV2` |

`isWhitelisted(context, account)` returns true if the context is globally open **or** the explicit `(context, account)` record is set. The context is typically the Fleet performing the check.

## Reference

Generated NatSpec for the access contracts:

- [`ProtocolAccessManager`](../contracts/access/reference/contracts/protocol-access-manager.md)
- [`ProtocolAccessManagerV2`](../contracts/access/reference/contracts/protocol-access-manager-v2.md)
- [`ProtocolAccessManaged`](../contracts/access/reference/contracts/protocol-access-managed.md)
- [`ProtocolAccessManagedV2`](../contracts/access/reference/contracts/protocol-access-managed-v2.md)
- [`LimitedAccessControl`](../contracts/access/reference/contracts/limited-access-control.md)
- [`IProtocolAccessManager`](../contracts/access/reference/interfaces/i-protocol-access-manager.md)
- [`IProtocolAccessManagerV2`](../contracts/access/reference/interfaces/i-protocol-access-manager-v2.md)
