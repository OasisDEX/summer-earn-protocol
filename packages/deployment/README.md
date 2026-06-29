# Summer Protocol Deployment Package

This package (`@summerfi/deployment`) contains Hardhat-based deployment scripts, Hardhat Ignition
modules, chain/network configuration, and Merkle tree generation tools for the Summer protocol. It
is the authoritative source of all on-chain addresses: every deploy script writes its results back
into `config/index.json` (or `config/index.test.json` for staging) via
`scripts/helpers/update-json.ts`.

## Key contracts and exports

- **Ignition modules** (`ignition/modules/`): `gov.ts`, `gov-v2.ts`, `core.ts`, `fleet.ts`,
  `fleet-whitelist.ts`, `institution-whitelist.ts`, and 36 per-ark modules under
  `ignition/modules/arks/`.
- **Types** (`types/config-types.ts`): `SupportedNetworks` enum (mainnet, base, arbitrum, sonic,
  hyperliquid), `ArkType` enum (35 types) with a parallel `arkTypes` prompt-choices array,
  `BaseConfig`, `FleetConfig`, `FleetDeployment`, `ArkConfig`.
- **Chain helpers**: `SupportedChain` enum and hand-maintained `SUPPORTED_CHAINS` array
  (`scripts/helpers/chain.ts`), `CHAIN_CONFIG_MAP` / `RPC_URL_MAP`
  (`scripts/common/chain-config-map.ts`), `getChainConfigs()` literal per-chain block
  (`scripts/helpers/chain-configs.ts`).
- **Config** (`config/index.json`, `config/index.test.json`): per-chain address maps (base,
  arbitrum, mainnet, sonic, hyperliquid in prod; optimism and unichain additionally in test).
  Re-exported with the `dstEidToChainIdMap` in `config/index.ts`.
- **Institution configs** (`config/institutions/<Name>/index.json`): governor, curator, guardian,
  superKeeper, whitelistManagers, timelock delays, and all deployed contract addresses per
  institution.

## Build and test commands

```bash
pnpm build                  # forge build (Solidity only; also --extra-output-files abi)
pnpm build:hh               # hardhat compile (for Ignition / TypeChain artifacts)
pnpm coverage               # forge coverage --ir-minimum
pnpm coverage:lcov          # generate lcov.info
pnpm coverage:report        # lcov.info → HTML report
```

## Deployment commands

All deploy scripts require `NETWORK=<network>` to be set (matches a key in `hardhat.config.ts`
`networks` block).

```bash
NETWORK=<net> pnpm deploy:gov                   # gov.ts module: ProtocolAccessManager, TimelockController, SummerToken, SummerGovernor, RewardsRedeemer
NETWORK=<net> pnpm deploy:gov-v2                # gov-v2.ts module
NETWORK=<net> pnpm deploy:staking               # StakedSummerToken, SummerStaking, SummerVestingWalletsEscrow
NETWORK=<net> pnpm deploy:core                  # DutchAuctionLibrary, ConfigurationManager, TipJar, HarborCommand, Raft, AdmiralsQuarters, FleetCommanderRewardsManagerFactory
NETWORK=<net> pnpm deploy:fleet                 # interactive: pick fleet config from config/fleets/
NETWORK=<net> pnpm deploy:ark                   # interactive: pick ark type (dispatches through scripts/common/ark-deployment.ts)
NETWORK=<net> pnpm deploy:institution           # scripts/deploy-institution-whitelist.ts
NETWORK=<net> pnpm deploy:institution-fleet     # scripts/deploy-whitelisted-fleet.ts
NETWORK=<net> pnpm deploy:institution-handover  # scripts/handover-institution-timelock.ts (run once, revokes deployer roles)
NETWORK=<net> pnpm deploy:buy-and-burn
NETWORK=<net> pnpm deploy:dao-tip-jar

# Status / verification
pnpm deploy:status:arbitrum   # hardhat ignition status chain-42161
pnpm deploy:status:base       # hardhat ignition status chain-8453
pnpm verify:mainnet           # hardhat ignition verify chain-1
pnpm verify:arbitrum          # chain-42161
pnpm verify:base              # chain-8453
pnpm verify:sonic             # chain-146
pnpm verify:hyperliquid       # chain-999
pnpm verify:all               # mainnet + arbitrum + base + sonic + hyperliquid

# Merkle tree
pnpm generate-merkle-root     # tsx scripts/generate-merkle-root.ts
```

## Cross-package connections

**Consumes** (workspace dependencies):

- Solidity sources (runtime dep): `@summerfi/earn-protocol-contracts`.
- Solidity sources (devDependencies): `@summerfi/access-contracts`, `@summerfi/config-contracts`,
  `@summerfi/earn-gov-contracts`, `@summerfi/chain-bridge-contracts`, `@summerfi/dutch-auction`,
  `@summerfi/rewards-contracts`, `@summerfi/voting-decay`, `@summerfi/percentage-solidity`.
- Utilities (devDependencies): `@summerfi/constants`, `@summerfi/math-utils`,
  `@summerfi/tenderly-utils`.

**Consumed by** (address propagation is manual, not automatic):

- `packages/summer-earn-rwa-app` — `src/config/institutions.ts` hand-mirrors
  `config/institutions/<Name>/index(.test).json`; must be refreshed manually after each institution
  or fleet deploy.
- `packages/summer-earn-interface` — syncs `config/index.json` into `src/config/deployment/`; no
  automatic propagation.

**Agent gotchas — hand-maintained lists that must be updated together:**

1. **Two chain enums**: `SupportedChain` in `scripts/helpers/chain.ts` (plus its `SUPPORTED_CHAINS`
   array) AND `SupportedNetworks` in `types/config-types.ts` are independent. Adding a chain
   requires editing both files.
2. **`getChainConfigs()` is a hand-written literal block** (`scripts/helpers/chain-configs.ts`), not
   derived from `SUPPORTED_CHAINS`. New chains must also be added there, in `CHAIN_CONFIG_MAP` /
   `RPC_URL_MAP` (`scripts/common/chain-config-map.ts`), in `config/index.json`,
   `config/index.test.json`, `config/index.ts`, and `hardhat.config.ts`.
3. **`ArkType` enum and `arkTypes` prompt array** live in the same file (`types/config-types.ts`)
   but are separate lists. Omitting the `arkTypes` entry hides the type from the interactive
   `deploy:ark` menu without error.
4. **`scripts/common/ark-deployment.ts` has two independent switch statements** (`deployArk` and
   `deployArkInteractive`). A new ark type must be added to both.
5. **`config/index.json` vs `config/index.test.json`** have diverged key sets (test has `optimism`
   and `unichain`; both have a not-yet-deployed `monad` key). Keep them consistent when adding new
   chain entries.
6. **`dstEidToChainIdMap`** in `config/index.ts` lists LayerZero endpoint IDs (`30184` base, `30110`
   arbitrum, `30332` sonic, `30101` mainnet) — hyperliquid eid 30367 is not present. Add it when
   wiring LZ governance for hyperliquid.
7. **`foundry.toml` `[rpc_endpoints]`** only lists `sepolia`, `base`, and `mainnet`;
   `hardhat.config.ts` covers five or more networks. Add fork-test chains to `foundry.toml`
   separately.
8. **Etherscan API keys** are committed in plaintext in `foundry.toml`; hardhat verification uses
   env vars.

## Institution (whitelisted) fleet deployment

Institution fleets are `FleetCommanderWhitelist` fleets scoped to a registered institution. Their
configs live under `config/institutions/<InstitutionId>/fleets/` and are selected interactively at
deploy time.

```bash
NETWORK=base pnpm deploy:institution-fleet      # gates on the V2 institution registry
NETWORK=base pnpm deploy:institution-fleet-v1   # gates on the legacy V1 institution registry
```

Both scripts are identical except for the pre-flight gate that verifies the institution is
registered:

- **`deploy:institution-fleet`** checks `institutionalVaultRegistryV2` (the default for new
  institutions).
- **`deploy:institution-fleet-v1`** checks the legacy `institutionalVaultRegistry` (V1) — for
  institutions that live in the V1 registry and have no V2 registry on the target network (e.g.
  `ExtDemoCorp_3` on Base). The registry is only a registration gate; the deploy runs on the
  already-deployed PAM / HarborCommand / AdmiralsQuarters, so the rest of the flow is identical.

The fleet config's `operatorType` selects how users interact with the fleet:

- `admiralsQuarters`: synchronous flow; AdmiralsQuarters is granted the OPERATOR role on the fleet.
- `roundsVaults`: asynchronous (RWA) flow; the deploy also creates input/output RoundsVaults and
  grants them the OPERATOR role. Requires a `roundsVaultRegistry` on the target network
  (`NETWORK=<net> pnpm deploy:rounds-vault-registry`).

If a `roundsVaults` (RWA) fleet was first deployed as `admiralsQuarters` and later retrofitted with
RoundsVaults, AdmiralsQuarters still holds the OPERATOR role. For RWA, deposits must flow only
through the input/output vaults, so revoke it with `NETWORK=<net> pnpm gov:revoke-aq-operator`
(executes directly if the deployer holds `GOVERNOR_ROLE`, otherwise captures a Safe batch).

## GitBook reference

[Deployment System](../../gitbook/internal/deployment.md) (`gitbook/internal/deployment.md`)
