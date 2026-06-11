---
description: Security model of the Summer.fi Earn Protocol — the role-based access model, privileged operations, immutability and migration strategy, external trust assumptions, and how to report vulnerabilities.
---

# Security and Audits

This section is written for security reviewers and auditors. Every claim here is grounded in the contract source under `packages/*/src`. Where a fact is operational (who holds a role in production, audit history, the bug-bounty contact) and cannot be derived from code, it is flagged with a `TODO (human input)` callout rather than asserted.

## Security model at a glance

The protocol's authority model is centralised in a single access-control contract and consumed everywhere else through thin, inheritable modifiers:

- **One source of truth for roles.** [`ProtocolAccessManager`](../contracts/access/reference/contracts/protocol-access-manager.md) holds every protocol-wide role. Contracts that need to gate functions inherit [`ProtocolAccessManaged`](../contracts/access/reference/contracts/protocol-access-managed.md), which exposes modifiers (`onlyGovernor`, `onlyKeeper`, `onlyGuardian`, …) that remote-query the manager. The manager reference is stored `immutable` in each consumer, so a contract cannot be re-pointed at a different authority after deployment.
- **Roles cannot be granted directly.** The manager extends [`LimitedAccessControl`](../contracts/access/reference/contracts/limited-access-control.md), which reverts `grantRole`/`revokeRole`. All grants flow through governor-gated wrapper functions; `renounceRole` is intentionally left enabled so a compromised account can drop its own role.
- **Governance is timelocked.** On-chain governance executes through an OpenZeppelin `TimelockController` ([`SummerTimelockController`](../governance/reference/contracts/summer-timelock-controller.md)), with a separate [`RwaTimelock`](../governance/reference/contracts/rwa-timelock.md) for the institutional RWA stack. The `minDelay` is a governable parameter.
- **Emergency backstop is separated from governance.** A time-bounded `GUARDIAN_ROLE` can pause Fleets and the bridge and cancel governance/timelock proposals, but holds strictly less power than the governor and expires on a schedule.
- **Contracts are largely immutable.** The protocol does not use upgradeable proxies for its core logic. New behaviour ships as freshly deployed `V2` contracts (migration-by-redeployment). See [Upgradeability](upgradeability.md).

## How this section is organised

| Page | Contents |
| --- | --- |
| [Roles and Access Control](roles-and-access-control.md) | The full roles matrix — every role, what it can do, and which contract/modifier enforces it. |
| [Privileged Operations](privileged-operations.md) | Governance, keeper, curator and guardian operations; timelock behaviour; pause/unpause surfaces. |
| [Upgradeability](upgradeability.md) | Immutability, migration-by-redeployment, the `V2` pattern, and the deprecated `FleetProxy`. |
| [Trust Assumptions](trust-assumptions.md) | External dependencies (LayerZero, Stargate, CoW Protocol, Merkl, oracles, Ark venues) and per-dependency failure modes. |

## Deployed addresses

This section deliberately does not hand-copy contract addresses, which drift. The canonical, machine-readable record of deployed instances lives in the deployment package:

- Core per-chain deployments: `packages/deployment/deployments/arbitrum/` and `packages/deployment/deployments/base/`.
- Per-fleet deployment manifests: `packages/deployment/deployments/fleets/*_deployment.json`.

Reviewers should treat those JSON manifests as the authoritative address book and resolve role holders against the live `ProtocolAccessManager` on each chain.

## Reporting a vulnerability

> TODO (human input): Provide the security disclosure process — the security contact email / channel, the bug-bounty program URL and reward tiers, the supported scope (which packages/chains are in scope), and the expected response/triage SLA. None of this is encoded in the repository and must be supplied by the team.
