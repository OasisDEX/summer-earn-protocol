---
description: How institutional Fleets add per-fleet KYC, a single controlled entry path, and timelocked separation of powers on top of the standard Fleet model.
---

# Institutional and RWA Vaults

Alongside the permissionless Fleets described in [Fleets and Arks](fleets-and-arks.md), the protocol ships an **institutional** variant built for KYC-gated capital and real-world-asset (RWA) strategies. It reuses the same FleetCommander / Ark / buffer model, and adds three things: per-Fleet whitelisting, a single controlled entry path, and timelocked separation of powers.

## Whitelisted Fleets

An institutional Fleet is a [`FleetCommanderWhitelist`](../contracts/core/reference/contracts/fleet-commander-whitelist.md) — a full ERC4626 vault that refuses anonymous interaction without breaking ERC4626 conformance. Every entry, exit, and share transfer checks a whitelist keyed on the **Fleet address as context**, brokered by [`ProtocolAccessManagerV2`](../contracts/access/reference/contracts/protocol-access-manager-v2.md):

```solidity
function isWhitelisted(address context, address account) public view returns (bool) {
    return _isWhitelistOpen[context] || _whitelisted[context][account];
}
```

A Whitelist Manager either opens a Fleet's whitelist to everyone (`setWhitelistOpen`) or approves specific accounts (`setWhitelisted` / `setWhitelistedBatch`). A **gateway** flag (`isOperatorGatewayOpen`) additionally switches the Fleet between operator-only mode (all user flow is routed through an audited entry contract) and direct whitelisted-user access.

## One entry path per Fleet

Two entry contracts exist, but a given Fleet is wired for **exactly one** of them at deployment (via its `operatorType`) — never both at the same time:

- [`AdmiralsQuartersWhitelist`](../contracts/core/reference/contracts/admirals-quarters-whitelist.md) — a **synchronous** multicall bundler for instant deposit/withdraw, used when the Fleet's funds settle on-chain.
- [`RoundsVault`](../contracts/core/reference/contracts/rounds-vault/rounds-vault-base.md) — an **asynchronous** batch layer for funds that settle T+1 off-chain against a NAV strike (see [RWA Arks and Asynchronous Settlement](rwa-arks-and-settlement.md)).

The active path holds `OPERATOR_ROLE` on the Fleet so it can pass the gateway on the user's behalf; the unused path is simply not granted that role (on a RoundsVault Fleet the deployment explicitly revokes AdmiralsQuarters' operator role, and an AdmiralsQuarters Fleet deploys no RoundsVault). Whichever path is active, a user must be whitelisted on the Fleet context — no role grants a bypass on the user side, so a single `setWhitelisted(fleet, user)` authorizes them on that Fleet's one active path.

## Separation of powers, under timelock

Institutional deployments split authority across roles that are deliberately kept apart, and each institution gets its **own** `ProtocolAccessManagerV2` plus three `RwaTimelock`s (Governor / Curator / Treasury) so one institution's governance can never reach another's Fleets:

| Role | Holds | Cannot |
| --- | --- | --- |
| **Curator** | Selects the Ark set, sets per-Ark caps and rebalance limits, directs allocation | Touch user funds; bypass the whitelist; change access control |
| **Keeper** | Executes rebalances within curator-set caps; runs the round settlement cycle | Exceed caps; withdraw to itself; alter configuration |
| **Governor** | Access-control changes and emergency paths (pause, round rollback) | Act instantly — every action passes the governor timelock |
| **Whitelist Manager** | Onboards/offboards accounts per Fleet | Anything outside whitelist state |

Because the Governor grants the other roles, it can in principle grant itself `WHITELIST_MANAGER_ROLE` and edit a whitelist — but the Governor is an `RwaTimelock`, so any such change is enqueued, publicly visible on-chain, and executes only after the configured delay, never instantly. See [Roles and Access Control](../security/roles-and-access-control.md) for the full role catalog.

## Where RWA fits

Institutional Fleets are how the protocol holds **regulated RWA fund tokens** — tokenized treasuries, money-market funds and private credit — behind a single ERC4626 share, with a professional curator selecting the funds. The connectors and the settlement machinery that makes off-chain-settled funds safe to pool are covered in [RWA Arks and Asynchronous Settlement](rwa-arks-and-settlement.md).
