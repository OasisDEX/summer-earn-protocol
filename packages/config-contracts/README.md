# @summerfi/config-contracts

Protocol-wide configuration registry. `ConfigurationManager` stores five system addresses — `raft`,
`tipJar`, `treasury`, `harborCommand`, and `fleetCommanderRewardsManagerFactory` — that every fleet
and ark reads at runtime through the `ConfigurationManaged` base contract. All setter functions are
gated to `onlyGovernor` via `ProtocolAccessManaged`.

## Key contracts

| Contract                        | Description                                                                                                                                     |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `ConfigurationManager`          | Standard deployment; all five addresses required at `initializeConfiguration`                                                                   |
| `ConfigurationManagerWhitelist` | Institution variant; accepts `fleetCommanderRewardsManagerFactory = address(0)` at init and reverts on `setFleetCommanderRewardsManagerFactory` |
| `ConfigurationManaged`          | Abstract base; contracts inherit this to read config fields via `configurationManager`                                                          |
| `IConfigurationManager`         | Interface consumed by the rest of the protocol                                                                                                  |

## Build / test

```sh
pnpm build       # forge build --quiet
pnpm test        # forge test
pnpm coverage    # forge coverage --ir-minimum
pnpm docs:gen    # forge doc
```

## Cross-package connections

**Consumes:** `@summerfi/access-contracts` (ProtocolAccessManaged), `@summerfi/dependencies`

**Consumed by:** `core-contracts`, `gov-contracts`, `deployment`, `intent-system`

**Gotchas:**

- `ConfigurationManagerWhitelist.initializeConfiguration` does **not** require
  `fleetCommanderRewardsManagerFactory` to be non-zero (the `address(0)` check is absent for that
  field). Calling `setFleetCommanderRewardsManagerFactory` on this variant always reverts with
  `NotSupported()`. This is intentional for institution deployments.
- For institution deployments the `treasury` field is set to the institution's `RwaTimelock`
  (TreasuryTimelock) address, not a plain treasury EOA or multisig.
- `ConfigurationManager.initializeConfiguration` can only be called once (`initialized` flag); there
  is no upgrade path for the full parameter set — individual setters must be used after init.

## GitBook reference

[contracts/config/reference](../../gitbook/contracts/config/reference/README.md)
