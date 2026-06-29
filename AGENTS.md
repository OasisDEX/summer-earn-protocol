# Agents

This file references skills and knowledge available to AI agents working on this repository.

## Skills

Skills are structured guides that encode domain-specific rules, patterns, and gotchas for common
development tasks in this codebase.

### Ark Development

**Path**:
[`summer-earn-protocol/packages/skills/ark-development/SKILL.md`](packages/skills/ark-development/SKILL.md)

Comprehensive guide for implementing new Ark contracts. Covers:

- Architecture decision (sync vs async, ERC4626 vs custom)
- Required overrides and implementation rules
- Gotchas: fork test setup order, diamond inheritance, decimal scaling, fee estimation
- Code style and file organization conventions
- Testing patterns and minimum test cases
- Reference implementations for each Ark pattern

### Protocol Deployments

**Path**:
[`summer-earn-protocol/packages/skills/deployment/SKILL.md`](packages/skills/deployment/SKILL.md)

Guide for adding new Arks and protocols to the deployment system using Hardhat Ignition and
interactive scripts.

## Documentation Pipeline

Published docs live in [`gitbook/`](gitbook/) and are split into **generated** and **hand-written**
trees. Knowing which is which is the single biggest gotcha — editing a generated page is wasted
work.

- **Generated (do NOT hand-edit):** every `reference/` subtree plus the two library subtrees, i.e.
  `gitbook/contracts/{core,dutch-auction,access,config,rewards,oracles}/reference/`,
  `gitbook/contracts/libraries/{percentage,price,math}/`, `gitbook/governance/reference/`, and
  `gitbook/governance/voting-decay/`. Each is produced by `scripts/docs/assemble.mjs` from
  `forge doc` output and is **wiped and rewritten on every build** — along with its `_nav.json` and
  `README.md`. To change one of these pages, edit the Solidity **NatSpec** in the source contract
  and rerun the build. `gitbook/SUMMARY.md` is likewise generated from
  `scripts/docs/summary.template.md` (only the template is hand-edited). The package→output mapping
  lives in `scripts/docs/docs.config.json`.
- **Hand-written (edit directly):** everything else — `gitbook/introduction/`, `concepts/`, `apis/`,
  `data/`, `security/`, `internal/`, the prose `governance/` pages (`overview.md`, `sip-process.md`,
  `staking-and-rewards.md`, `sumr-token.md`, `vesting.md`), and `contracts/architecture.md` /
  `contracts/ark-catalog.md`.

Commands (root `package.json`): `pnpm docs:gen` (per-package `forge doc` via turbo →
`docs/generated/`), `pnpm docs:assemble` (clean + assemble into `gitbook/`), `pnpm docs:build`
(both), `pnpm docs:check` (build then `git diff --exit-code -- gitbook/`). After ANY NatSpec edit,
run `pnpm docs:build` and commit the regenerated `gitbook/` in the same change.

CI (`.github/workflows/docs.yaml`): PRs run a **drift check** (`pnpm docs:build` must leave
`gitbook/` clean); pushes to `main` auto-regenerate and commit `[skip ci]` as a safety net. Foundry
is pinned (`v1.5.1`) because `forge doc` output format can shift between versions and flap the drift
check.

NatSpec & audit tooling (`scripts/audit/`):

- Each documented contract package needs `extra_output = ["devdoc", "userdoc"]` and a `[doc]` block
  in its `foundry.toml`, plus a `docs:gen` script — without these `forge doc` / the coverage auditor
  silently miss content.
- `natspec-coverage.py` cross-references ABI vs solc devdoc/userdoc (resolves `@inheritdoc`);
  reports land under `docs/audit/<period>/`.
- `check-comment-only.py` verifies a NatSpec-only edit is **bytecode-identical** modulo CBOR
  metadata (compare two `out/` dirs). Use it to prove a doc wave changed no executable code.

Adding a new documented contract package: add it to `scripts/docs/docs.config.json`
(`{package, section, out}`) AND give its `foundry.toml` the `[doc]` + `extra_output` + `docs:gen`
scaffolding, then `pnpm docs:build`.

## Cross-Package Change Checklists

Ordered, file-level checklists for changes that ripple across packages. Address propagation in this
repo is almost entirely manual — `packages/deployment/config/index.json` is the source of truth, but
subgraph configs and app configs are hand-maintained copies.

### Package Map

- **Contracts** (`core-contracts`, `gov-contracts`, `access-contracts`, `config-contracts`,
  `rewards-contracts`, `dutch-auction`, `rwa-oracles`) — Foundry packages; `core-contracts` holds
  Arks/FleetCommander, `pnpm build` runs `forge build` + an ABI-copy step.
- **Deployment** (`deployment`) — Hardhat + Ignition. Deploy scripts write addresses back into
  `config/index.json` (prod) / `config/index.test.json` (staging "bummer") via
  `scripts/helpers/update-json.ts`. Institution configs live in `config/institutions/<Name>/`.
- **Subgraphs** (`summer-earn-protocol-subgraph`, `-rates-`, `-protocol-gov-`, `-institutions-`,
  `-institutions-v2-`, `-auctions-`, `-dca-subgraph`) — each has per-chain `config/<network>.json`
  (addresses + start blocks, hand-copied from deployment outputs), mustache-templated
  `subgraph.template.yaml`, and `prepare:/build:/deploy:<network>` scripts deploying to Goldsky with
  `$npm_package_version` as the deployment tag.
- **Apps/services** (`summer-earn-interface`, `summer-earn-rwa-app`, `summer-earn-dca-app`,
  `summer-earn-auctions-frontend`, `summer-earn-gov-validator`, `summer-earn-gov-alert-bot`,
  `oracle-cli`, `oracle-dashboard`, `ark-rebalancer`) — consume deployment addresses either via a
  `pnpm sync-config` script (gov-validator, interface, gov-alert-bot copy from
  `packages/deployment`) or via fully hand-maintained config files (rwa-app, dca-app,
  auctions-frontend, oracle-dashboard). Subgraph Goldsky slugs are hand-listed per chain in each
  app's config.
- **Shared libs** (`percentage`, `price-utils`, `math-utils`, `voting-decay`, `constants`,
  `external-dependencies`, `legacy-dependencies`, `eslint-config`, `jest-config`,
  `typescript-config`, `tenderly-utils`) — Solidity/TS libraries and base configs consumed by the
  above.

### Add a new Ark type (new contract + deploy support)

1. `skills` — read `packages/skills/ark-development/SKILL.md` FIRST. It mandates the base-contract
   choice (Ark / ERC4626Ark / ArkWithWithdrawalRequest / BasePendleArk), conservative
   `_withdrawableTotalAssets()`, split interface/error/event files, and fork-test-first setup order.
   Do not re-derive these rules.
2. `core-contracts` — implement `src/contracts/arks/<New>Ark.sol` (~40 existing siblings,
   AaveV3Ark…WisdomTreeArk), with split files under `src/interfaces/`, `src/errors/`, `src/events/`
   (pattern `I<X>Events.sol`). Fork tests under `test/` use `<CHAIN>_RPC_URL` via `foundry.toml`
   `[rpc_endpoints]`. Build: `pnpm build`; run `pnpm format:fix` after edits.
3. `deployment/types/config-types.ts` — register the type in TWO places in the same file: the
   `ArkType` enum (line ~15) AND the `arkTypes` prompt-choices array (line ~53). Forgetting the
   array silently hides the type from the interactive `deploy:ark` menu.
4. `deployment/types/ark-params.ts` — add the ark's constructor-params type.
5. `deployment/ignition/modules/arks/<new>-ark.ts` — add the Ignition module (36 existing examples).
6. `deployment/scripts/arks/deploy-<new>-ark.ts` — add the per-type deploy script (34 existing
   siblings).
7. `deployment/scripts/common/ark-deployment.ts` — add the new `ArkType` to BOTH switch statements:
   `deployArk()` (config-driven) and `deployArkInteractive()` (prompt-driven). These are independent
   dispatchers.
8. `deployment/scripts/helpers/zod-schemas.ts` (+ `validation.ts`, which imports `ArkDetailsSchema`)
   — extend validation if the ark needs new config fields.
9. `deployment/config/index.json` — add protocol-specific addresses under
   `<network>.protocolSpecific`; mirror in `index.test.json` for staging. Reference the ark type in
   `config/fleets/<chain>-<TOKEN>-N.json` (and `.bummer.json` variants /
   `config/institutions/<Name>/fleets/*.json`).
10. `deployment` — deploy: `NETWORK=<chain> pnpm deploy:ark` (interactive `scripts/deploy-ark.ts`);
    optionally add a dedicated `deploy:<new>-ark` package.json script (pattern: `deploy:aavev3-ark`,
    `deploy:pendle-pt-ark`). Add a curation row in `config/curation/arks.json` (and the
    institution-scoped copy) — consumed by curation/governance proposal scripts.
11. `summer-earn-rates-subgraph` — if no existing product fits the underlying protocol: add
    `src/products/<New>Product.ts` (22 existing, e.g. `AaveV3Product.ts`), register it in the
    `init<Network>()` method(s) in `src/config/protocolConfig.ts`, add addresses to
    `src/constants/addresses.ts`, new ABIs under `abis/` + `subgraph.template.yaml` abis list if
    needed. Bump version in `package.json`, set grafting fields in `config/<network>.json`, then
    `pnpm deploy:<network>`.
12. `summer-earn-protocol-subgraph` — usually no change (arks are indexed generically via
    templates). Only update `abis/Ark.abi.json` / `src/utils/ark.ts` + redeploy if the ark's
    `details()` JSON or event interface differs from the template ABI.
13. `gitbook` — add a row to `gitbook/contracts/ark-catalog.md` (category tables link to
    `contracts/core/reference/contracts/arks/`) and update the "Supported Ark types" count/list in
    `gitbook/internal/deployment.md` (it hard-codes the ArkType member count).

### Deploy a new Ark or Fleet (existing type)

1. On-chain wiring is the trigger for most indexing: `summer-earn-protocol-subgraph`'s HarborCommand
   data source handles `FleetCommanderEnlisted(indexed address)` and spawns
   `FleetCommanderTemplate`, which handles `ArkAdded(indexed address)` and spawns `ArkTemplate`
   (`subgraph.template.yaml`). No subgraph change needed for a new fleet/ark unless the
   HarborCommand address itself changed (`config/<network>.json` `harbor-command-address`).
2. `summer-earn-rates-subgraph/src/config/protocolConfig.ts` — required if the ark targets a
   protocol/pool not yet tracked: add a `Product` in the correct `init<Network>()` method. The
   Product id `${groupName}-${assetAddress}-${poolAddress}-${chainId}` (`src/models/Product.ts`)
   MUST match the ark's on-chain `details()` JSON (parsed by `getArkProductId` in
   `summer-earn-protocol-subgraph/src/utils/ark.ts`, keys protocol/pool/vault/siUSDVault/chainId) or
   rate correlation silently misses. New token addresses go in `src/constants/addresses.ts`. Bump
   `package.json` version (convention `1.23.4-<change-slug>`), set `grafting-base`/`grafting-block`
   in `config/<network>.json` to avoid a full resync, then `pnpm deploy:<network>`.
3. `summer-earn-auctions-subgraph` — nothing for the ark itself: Raft data sources spawn from
   ConfigManager `RaftUpdated` / registry `InstitutionAdded` events; per-ark auction params arrive
   via `ArkAuctionParametersSet`.
4. `summer-earn-institutions-subgraph` / `-v2-` — nothing in the manifests (`ArkAdded` handled by
   templates), but the same ark-details-to-rates-product-id coupling applies for institutional arks
   (see step 2).
5. `summer-earn-gov-validator` and `summer-earn-interface` — re-run `pnpm sync-config` in each so
   `src/config/...` picks up the new addresses from `packages/deployment`. Interface fleet discovery
   at runtime goes through `HARBOR_COMMAND_ADDRESSES` in `src/config/environments.ts` plus the
   subgraphs.
6. `summer-earn-dca-app` — fleets are discovered on-chain via the hand-copied HarborCommand address;
   only extend `src/config/addresses.ts` (`KNOWN_TOKEN_ADDRESSES`, `FEED_BY_ASSET_ADDRESS`) if the
   fleet uses a new underlying token.
7. `ark-rebalancer` — point the `FLEET_COMMANDER_ADDRESS` env var at the new fleet; arks are
   enumerated on-chain via `fleetCommander.arks()` (`ark_rebalancer.py`, ABIs inlined).

### Enable a new chain

Repo plumbing:

1. `turbo.json` — add `<CHAIN>_RPC_URL` to `globalEnv` (currently
   MAINNET/ARBITRUM/BASE/SONIC/OPTIMISM/HYPERLIQUID). Without this, turbo strips the var from task
   environments and cache keys.
2. `.github/workflows/build-unit-test.yaml` — add `<CHAIN>_RPC_URL: ${{ secrets.<CHAIN>_RPC_URL }}`
   to the env block and create the GitHub secret.
3. Repo-root `.env` (untracked) — add `<CHAIN>_RPC_URL`. Subgraph deploy scripts
   `source ../../.env`; `deployment/hardhat.config.ts` loads it via dotenv.
4. `core-contracts/foundry.toml` — add `<chain> = "${<CHAIN>_RPC_URL}"` to `[rpc_endpoints]` for
   fork tests; same for `deployment/foundry.toml` if needed (currently only sepolia/base/mainnet
   there).

`deployment` package:

5. `scripts/helpers/chain.ts` — add to the `SupportedChain` enum AND the separate hand-maintained
   `SUPPORTED_CHAINS` array.
6. `scripts/common/chain-config-map.ts` — add `RPC_URL_MAP` and `CHAIN_CONFIG_MAP` entries (use
   `defineChain()` if not in viem/chains, like hyperliquid id 999). `CHAIN_MAP_BY_ID` is derived.
7. `scripts/helpers/chain-configs.ts` — add a literal entry to `getChainConfigs()` ({chain, config,
   rpcUrl}); not derived from `SUPPORTED_CHAINS`.
8. `types/config-types.ts` — add to the `SupportedNetworks` enum (a second chain enum, independent
   from `SupportedChain`).
9. `config/index.json` + `config/index.test.json` — add the top-level chain key with the standard
   shape (`deployedContracts` {gov, govV2, core, …}, tokens, common, protocolSpecific, bridge). Key
   sets already diverge between the two files.
10. `config/index.ts` — add the chain to the exported `config` map; if it participates in LayerZero
    governance, add its endpoint id to `dstEidToChainIdMap`. Add a `config/adapters/layerzero.json`
    chainConfig entry keyed by numeric chain id for cross-chain messaging.
11. `hardhat.config.ts` — add the `networks` entry (RPC from env, chainId, accounts) and
    `etherscan.customChains` if the explorer is not natively supported (pattern: sonic 146,
    hyperliquid 999).
12. `package.json` — optionally add `deploy:status:<chain>`; then run bootstrap deploys in order:
    `deploy:gov` / `deploy:gov-v2`, `deploy:core` (each writes back into `config/index.json`), then
    fleets/arks. Downstream consumers are NOT auto-refreshed.

Subgraphs (each: per-chain config json + `prepare:/build:/deploy:<network>` scripts + `deploy:all`
list in package.json):

13. `summer-earn-protocol-subgraph` — `config/<chain>.json` (network, harbor-command-address + start
    block, governance-rewards-manager, summer-staking-v2 prod+staging,
    interval-handler-block-interval, grafting). Also hand-extend `src/common/addressProvider.ts`
    `getAddressesProvider()` with a new network branch (~40 token/oracle addresses — the big
    gotcha). Goldsky slug `summer-protocol-<chain>`.
14. `summer-earn-rates-subgraph` — `config/<chain>.json` (entry_point_address + start block);
    network branch in `src/constants/addresses.ts` (graph-node slugs: `arbitrum-one`,
    `sonic-mainnet`, `hyperliquid`/`hyperevm`) AND `src/utils/chainId.ts` `getChainIdByNetworkName`
    (unknown networks break product ids) AND a new `init<Chain>()` in `src/config/protocolConfig.ts`
    wired into its constructor switch.
15. `summer-earn-protocol-gov-subgraph` — `config/<chain>.json` (governor v1+v2, timelock,
    protocol-access-manager, harbor-command, governance token + start blocks; unused contracts
    zero-address as on hyperliquid/arbitrum).
16. `summer-earn-institutions-subgraph` — `config/<chain>.json` (registry-address =
    InstitutionalVaultRegistry v1) + extend its own copy of `src/common/addressProvider.ts`.
17. `summer-earn-institutions-v2-subgraph` — TWO config files (`<chain>.json` +
    `<chain>-staging.json`; registry v2 + rounds-vault-registry addresses, zero-address placeholders
    allowed) and TWO script sets (`deploy:<chain>`, `deploy:<chain>-staging`) plus
    `deploy:all`/`deploy:all-staging`. Extend its own `addressProvider.ts` copy.
18. `summer-earn-auctions-subgraph` — `config/<chain>.json` (nested
    `config-manager{address,start-block}`, `institutional-vault-registry{…}`; zero-address if
    absent). Currently only mainnet/base/arbitrum/sonic — no hyperliquid.
19. `summer-earn-dca-subgraph` — only base + mainnet exist. `config/<chain>.json` needs
    dca-strategy-manager address/start-block, feed-start-block (~14d earlier), and usdc/eth
    Chainlink PROXY addresses (never impl addresses — the once-block handler resolves aggregators
    itself). Per its CLAUDE.md, update that file in the same commit.

Apps/services (subgraph Goldsky slugs and addresses are hand-listed per chain in each):

20. `summer-earn-interface` — `src/config/chains.ts` (CHAIN_NAMES, CHAIN_RPC_URLS,
    CHAIN_BLOCK_EXPLORERS, VIEM_CHAIN_ENTITIES + four subgraph URL maps: rates, institutions,
    protocol, governance); `src/config/environments.ts` (every
    `Record<Environment, Record<number, Address>>` map for both production and staging);
    `scripts/sync-config.js` CHAIN_NAMES then `pnpm sync-config` (writes
    `src/config/deployment/index.json` + `deployed/<chain>.json`).
21. `summer-earn-rwa-app` — `src/types/chain.ts` (ChainId union AND SUPPORTED*CHAIN_IDS array);
    `src/config/chains.ts` (FIVE records: CHAIN_NAMES, CHAIN_RPC_URLS, CHAIN_BLOCK_EXPLORERS,
    DEFAULT_INSTITUTIONS_V2_URLS production+staging, VIEM_CHAIN_ENTITIES); `src/config/env.ts`
    (NEXT_PUBLIC_INSTITUTIONS_V2_SUBGRAPH_URL*<CHAIN> override key).
22. `summer-earn-gov-validator` — `scripts/sync-config.js` CHAIN*NAMES (chains without a mapping are
    silently skipped with only a console warning) + `pnpm sync-config`; `src/config/constants.ts`
    (CHAINS array with LayerZero eID + hand-maintained CHAIN_CONFIG timelock/summerToken);
    `src/config/rpc.ts` (VIEM_CHAIN_ENTITIES, CHAIN_RPC_URLS); also chain-keyed `tokenLists.ts`,
    `treasuryWallets.ts`, `src/services/subgraph.ts` (per-chain NEXT_PUBLIC*\*\_SUBGRAPH_URL
    defaults), and CHAIN_THEMES in chains.ts.
23. `summer-earn-gov-alert-bot` — `scripts/sync-config.js` CHAIN_NAMES (currently missing
    hyperliquid 999 — already drifted from the other two sync scripts) + sync; `src/config.ts`
    viemChains/SupportedNetworks; `src/config/rpc.ts` (near-duplicate of gov-validator's).
24. `summer-earn-dca-app` — currently Base-only: `src/config/chains.ts` + `src/config/addresses.ts`
    (DCA_STRATEGY_MANAGER_ADDRESSES, HARBOR_COMMAND_ADDRESSES, KNOWN_TOKEN_ADDRESSES,
    FEED_BY_ASSET_ADDRESS).
25. `summer-earn-auctions-frontend` — `src/lib/config.ts` CHAIN_CONFIGS entry (subgraphEndpoint,
    raftAddress hand-copied, `<CHAIN>_RPC_URL` env var).
26. `oracle-cli` — `src/config.ts` (DeployNetwork union, VIEM_CHAINS, RPC_ENV_KEYS/CANDIDATES;
    currently only base/arbitrum/mainnet/sonic). `oracle-dashboard` — `config/chains.ts`
    CHAIN_RPC_URLS + hand-copy `deployments.json`/`yield-deployments.json` from oracle-cli into
    `lib/`.
27. `gitbook/internal/deployment.md` — update the internal deployment docs (deploy commands take
    `--network $NETWORK`; fleet config naming `<chain>-<TOKEN>-N.json`).

### Deploy / onboard a new institution (whitelist flow)

1. `deployment/config/institutions/<InstitutionId>/index.json` (`index.test.json` for
   staging/"bummer") — create with per-network governor[], curators[], guardian[], superKeeper,
   whitelistManagers[], and a MANDATORY `timelock` block {governorDelay, curatorDelay,
   treasuryDelay} in seconds (0 = immediate; max 365 days via `MAX_TIMELOCK_DELAY_SECONDS` in
   `scripts/helpers/zod-schemas.ts`). Schemas are strict zod — unknown keys are rejected, and any
   new contract key MUST be added to `InstitutionNetworkDeployedContractsSchema` or its recorded
   address is stripped on the next index write.
2. `deployment` — run `NETWORK=<net> pnpm deploy:institution`
   (`scripts/deploy-institution-whitelist.ts`). Prompts prod vs bummer + institution id, validates
   config, then deploys via `ignition/modules/institution-whitelist.ts`: ProtocolAccessManagerV2 +
   THREE RwaTimelocks (Governor/Curator/Treasury — the treasury RwaTimelock IS the
   ConfigurationManager treasury) + ConfigurationManagerWhitelist + TipJar + HarborCommand + Raft
   (linked DutchAuctionLibrary) + AdmiralsQuartersWhitelist. Registers the institution in
   InstitutionalVaultRegistry V2, grants roles, grants GOVERNOR_ROLE to the governor timelock, and
   writes all addresses back into the institution index. Re-running is idempotent (missing timelocks
   deployed directly, recorded ones verified with `assertTimelockUsable`).
3. `deployment/config/institutions/<InstitutionId>/fleets/<network>-<ASSET>-<n>.json` — add
   per-fleet definition (fleetName, symbol, assetSymbol, depositCap, curator = the institution's
   curatorTimelock, operatorType e.g. roundsVaults, arks[]), then `pnpm deploy:institution-fleet`
   (`scripts/deploy-whitelisted-fleet.ts`). Refuses to deploy unless the institution is registered;
   writes fleet addresses (fleetCommander, bufferArk, arks, roundsVaultInput/Output) into the
   institution index.
4. `deployment` — run ONCE at the end: `pnpm deploy:institution-handover`
   (`scripts/handover-institution-timelock.ts`). Verifies all three timelocks, ensures the governor
   timelock holds GOVERNOR_ROLE and the curator timelock holds CURATOR_ROLE on at least one fleet,
   then revokes the deployer's WHITELIST_MANAGER_ROLE and renounces its GOVERNOR_ROLE. Until this
   runs, the deployer keeps its bootstrap GOVERNOR_ROLE.
5. Subgraphs — normally zero changes: `summer-earn-institutions-v2-subgraph` spawns templates from
   `InstitutionAdded(indexed bytes32,address,address,address)` and `RoundsVaultPairRegistered`; v1
   likewise via its registry. Only hand-edit `config/<network>.json` (registry-address /
   rounds-vault-registry-address) + version bump + redeploy if the registry contracts themselves
   change. Staging vs prod use separate registries via `config/<network>-staging.json` and
   `-staging` Goldsky slugs.
6. `summer-earn-auctions-subgraph` — auto via `InstitutionAdded`/`RaftUpdated`, BUT on chains where
   `institutional-vault-registry` is still 0x0 in `config/<network>.json` (base/mainnet today),
   institutional auction Rafts will NOT be picked up until the address is hand-filled and the
   subgraph redeployed.
7. `summer-earn-rwa-app/src/config/institutions.ts` — HAND-MAINTAINED: add a full Institution entry
   (slug, chainId, protocolAccessManager, timelocks + delays, configurationManager, harborCommand,
   admiralsQuarters, raft, tipJar, treasury, role arrays, every fleet's
   fleetCommander/bufferArk/arks/roundsVaults) to STAGING_INSTITUTIONS or PRODUCTION_INSTITUTIONS.
   The file header says it mirrors
   `packages/deployment/config/institutions/<name>/index(.test).json`; there is NO sync script.
   Adding an ark to an institution fleet also requires editing the fleet's `arks[]` here. Confirm
   the chain's institutions-v2 subgraph slug in `src/config/chains.ts` (production vs `-staging`).
8. `summer-earn-interface` — institutions surface through `CHAIN_INSTITUTIONS_SUBGRAPH_URLS` in
   `src/config/chains.ts` plus the synced deployment config; re-run `pnpm sync-config` after the
   deployment config changes.

### Governance contract changes (governor/timelock redeploy or govV2)

1. `summer-earn-protocol-gov-subgraph` — add the new governor/timelock addresses to
   `config/<network>.json` and redeploy; consumers depend on it indexing the new contracts.
2. `summer-earn-gov-validator` — re-run `pnpm sync-config` (pulls gov/govV2 from
   `deployment/config/index.json`); update hand-maintained `CHAIN_CONFIG` (timelock, summerToken) in
   `src/config/constants.ts` and the ABIs in `src/config/abis/` if the interface changed; gov
   subgraph endpoints in `src/services/subgraph.ts` must index the new governor.
3. `summer-earn-gov-alert-bot` — re-run `pnpm sync-config`; `getGovernorAddresses()` reads
   `deployedContracts.gov.summerGovernor` and `govV2.summerGovernor`, `getTimelockAddress()` reads
   `gov.timelock` from the synced `src/config/index.json` — a renamed config key breaks the bot
   silently.
4. `summer-earn-interface` — `CHAIN_GOVERNANCE_SUBGRAPH_URLS` in `src/config/chains.ts` must point
   at a gov subgraph indexing the new governor; re-run `pnpm sync-config` for addresses.

### New RWA oracle / yield token deployed

1. `oracle-cli` — `deploy.ts` / `deploy-yield.ts` record oracleRegistry + per-ticker oracle/asset
   addresses in `src/deployments.json` and yield-token/pocket addresses in
   `src/yield-deployments.json`.
2. `oracle-dashboard` — HAND-COPIED: `lib/deployments.json` and `lib/yield-deployments.json` are
   byte-identical copies of `oracle-cli/src/*.json`; no sync script exists in either package.json —
   copy manually after each oracle deployment.

<!-- BEGIN BEADS CODEX SETUP: generated by bd setup codex -->

## Beads Issue Tracker

Use Beads (`bd`) for durable task tracking in repositories that include it. Use the `beads` skill at
`.agents/skills/beads/SKILL.md` (project install) or `~/.agents/skills/beads/SKILL.md` (global
install) for Beads workflow guidance, then use the `bd` CLI for issue operations.

### Quick Reference

```bash
bd ready                # Find available work
bd show <id>            # View issue details
bd update <id> --claim  # Claim work
bd close <id>           # Complete work
bd prime                # Refresh Beads context
```

### Rules

- Use `bd` for all task tracking; do not create markdown TODO lists.
- Run `bd prime` when Beads context is missing or stale.
- Keep persistent project memory in Beads via `bd remember`; do not create ad hoc memory files.
<!-- END BEADS CODEX SETUP -->
