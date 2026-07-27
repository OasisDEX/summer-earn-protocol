---
description: The Summer.fi Earn Protocol's immutability stance — core contracts are not upgradeable, new behaviour ships as V2 redeployments, and FleetProxy is a cross-chain asset holder rather than an upgrade proxy.
---

# Upgradeability

## Contracts are largely immutable

The protocol does **not** use upgradeable proxies (EIP-1967 transparent/UUPS/beacon) for its core logic. Reviewers should treat each deployed contract's bytecode as fixed for its lifetime. Two structural facts reinforce this:

- **Immutable authority wiring.** Every contract that gates functions stores its access manager as `ProtocolAccessManaged._accessManager`, declared `immutable` and validated (via ERC-165) in the constructor. A contract cannot be re-pointed at a different `ProtocolAccessManager` after deployment.
- **Immutable venue wiring on Arks.** Ark implementations hold their external venue references in `immutable` state (for example `SyrupArkV2` declares `VAULT`, `MANAGER`, `WITHDRAWAL_MANAGER` and `ROUTER` as `immutable`; `SiloVaultArkV2` holds an `immutable silo`). An Ark therefore cannot be retargeted at a different underlying protocol — onboarding a new venue means deploying a new Ark.

There is no storage-gap / initializer pattern in these contracts; they use ordinary constructors, consistent with non-proxied deployment.

## Migration by redeployment (the V2 pattern)

Behavioural changes are delivered by deploying a **new contract** (conventionally suffixed `V2`) alongside the old one, then migrating governance/users over. The old contract keeps running for legacy consumers; there is no in-place upgrade and no shared proxy.

V2 contracts confirmed in source:

| V2 contract | Package | What it adds / changes (from NatSpec) |
| --- | --- | --- |
| `ProtocolAccessManagerV2` | access-contracts | Adds a per-contract `OPERATOR_ROLE`, a global `WHITELIST_MANAGER_ROLE`, and a per-context whitelist for institutional Fleet variants. "Replaces `ProtocolAccessManager` for institutional Fleet variants; legacy components keep using the V1 manager." |
| `ProtocolAccessManagedV2` | access-contracts | Enforces the manager implements `IProtocolAccessManagerV2`; adds the `onlyOperator` / `hasOperatorRole` hook. "Arks and legacy components continue to inherit from the base `ProtocolAccessManaged`." |
| `SummerGovernorV2` | gov-contracts | Cross-chain governor using a hub-and-satellite architecture: voting on the hub with xSUMR voting power; finalized proposals relayed to satellite chains via LayerZero for queuing and timed execution. |
| `SummerVestingWalletV2` | gov-contracts | Configurable cliff (timestamp + amount), monthly time-based release over a configurable number of periods, and custom performance goals; factory owner can mark goals reached and recall unvested tokens. |
| `SummerVestingWalletFactoryV2` | gov-contracts | Factory for `SummerVestingWalletV2` instances. |
| `SyrupArkV2` | core-contracts | Maple Finance Syrup Ark with signature-authorized deposits and a `ISyrupWithdrawalManagerV2` withdrawal path. |
| `SiloVaultArkV2` | core-contracts | Refined Silo vault Ark implementation. |

Consequences for reviewers:

- **V1 and V2 coexist.** The presence of a V2 does not retire the V1 instance on-chain. Determining which manager/governor/ark version a given Fleet actually uses requires reading the live deployment, not the source tree alone. Resolve this against `packages/deployment/deployments/`.
- **No upgrade attack surface, but a migration surface.** There is no `upgradeTo`/`upgradeToAndCall` to scrutinise. The equivalent risk is the governance process that re-points consumers (role grants, `enlist`/`decommission`, configuration setters) at new implementations — covered in [Privileged Operations](privileged-operations.md).

## FleetProxy is not an upgrade proxy

Despite the name, `FleetProxy` is **not** a logic/upgrade proxy. The `IFleetProxy` interface (`packages/core-contracts/src/interfaces/IFleetProxy.sol`) describes a **cross-chain satellite asset holder**: it inherits `ICrossChainReceiver` and exists to receive, hold, and send assets on a satellite chain on behalf of a Fleet on the source chain (its events are `ProxyDeposit`, `ProxyWithdrawal`, `AssetsSent`, `AssetsWithdrawnAndTransferred`). It does not delegatecall to an implementation and exposes no upgrade entry point.

It belongs to the legacy cross-chain Fleet path and should be treated as a deprecated component rather than part of the upgrade model. Auditors should not interpret "Proxy" here as an EIP-1967 upgrade proxy.

> TODO (human input): Confirm the current deployment/deprecation status of the FleetProxy cross-chain path — whether any `FleetProxy` instance is live on any satellite chain today, or whether the path is fully retired. The interface is present in source but no implementation ships under `packages/*/src`.

## Audit history

> TODO (human input): List completed audits (auditor, scope, commit/date) and link the published reports. No audit reports are embedded in the repository.
