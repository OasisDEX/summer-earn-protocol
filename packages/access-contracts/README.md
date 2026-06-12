# @summerfi/access-contracts

Role and access control layer for the Summer.fi earn protocol. It provides two
`ProtocolAccessManager` variants and the base contracts that protocol contracts inherit to enforce
role checks. `ProtocolAccessManager` (V1) defines the global roles used by the broader protocol;
`ProtocolAccessManagerV2` extends it with a per-context user whitelist and a per-contract
`OPERATOR_ROLE`, used exclusively by institutional Fleet variants. All role mutations go through
typed `grant*`/`revoke*` helpers rather than the raw OpenZeppelin `grantRole`/`revokeRole` API,
which `LimitedAccessControl` disables at the base level.

## Key contracts

| Contract                                            | Description                                                                                                                                                                                                                                                                                                                                            |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ProtocolAccessManager`                             | Central authority for global roles: `GOVERNOR_ROLE`, `GUARDIAN_ROLE`, `SUPER_KEEPER_ROLE`, `DECAY_CONTROLLER_ROLE`, `ADMIRALS_QUARTERS_ROLE`, `FOUNDATION_ROLE`, plus contract-scoped `CURATOR_ROLE`, `KEEPER_ROLE`, `COMMANDER_ROLE` (generated via `generateRole`). Guardians carry an explicit expiration timestamp enforced by `isActiveGuardian`. |
| `ProtocolAccessManagerV2`                           | Extends V1 with `WHITELIST_MANAGER_ROLE` and a per-context whitelist (`isWhitelisted`, `areWhitelisted`, `setWhitelistedBatch` — max 200 accounts per call). The constructor seeds the `governor` address with `WHITELIST_MANAGER_ROLE` in addition to `GOVERNOR_ROLE`. Used by institutional Fleet deployments.                                       |
| `ProtocolAccessManaged` / `ProtocolAccessManagedV2` | Abstract base contracts that downstream protocol contracts inherit to get role-checking modifiers pointing at the appropriate PAM instance.                                                                                                                                                                                                            |
| `LimitedAccessControl`                              | Base for both managers; disables `grantRole` and `revokeRole` from OZ `AccessControl` so all mutations must go through the typed helpers.                                                                                                                                                                                                              |

## Build and test

```sh
# Run Foundry tests
pnpm test

# Coverage (ir-minimum pipeline)
pnpm coverage

# Generate NatSpec docs (forge doc)
pnpm docs:gen

# Format Solidity files
pnpm format:fix
```

## Cross-package connections

**Consumes:** `@summerfi/dependencies` only (OpenZeppelin contracts and forge-std are re-exported
from there).

**Consumed by:** `config-contracts`, `rewards-contracts`, `core-contracts`, `gov-contracts`, and the
`deployment` package — every contract that inherits
`ProtocolAccessManaged`/`ProtocolAccessManagedV2` pulls this package as a transitive dependency.

**Agent gotchas:**

- `ProtocolAccessManagerV2`'s constructor grants `WHITELIST_MANAGER_ROLE` to the `governor` address
  passed at deployment. Institution handover scripts must explicitly revoke this role from the
  deployer/bootstrap address after the real Whitelist Manager is set, or the deployer retains
  whitelist mutation power.
- Contract-scoped roles (`CURATOR_ROLE`, `KEEPER_ROLE`, `COMMANDER_ROLE`, `OPERATOR_ROLE`) are
  derived by `generateRole(roleName, contractAddress)` — the role identifier changes with the target
  contract address. Any off-chain tooling that hard-codes role hashes must regenerate them per
  deployment.

## Reference docs

GitBook: [Access Control reference](../../gitbook/contracts/access/reference/README.md) — covers all
contracts and interfaces in this package. Roles overview:
[Roles & Access Control](../../gitbook/security/roles-and-access-control.md).
