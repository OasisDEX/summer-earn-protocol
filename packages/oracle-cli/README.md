# Summer Earn Oracle CLI

A TypeScript CLI for deploying and operating Summer Earn RWA Oracles (`OracleRegistry` and
`RwaOracle` contracts). It handles deployment, price-update signing and submission, WisdomTree
Connect API integration, NAV data fetching via the DataSpan API, and signer/registry management.

## Key contracts and source files

- `src/deploy.ts` — deploys `OracleRegistry` and `RwaOracle`; reads `deploy-input.json`, writes
  `src/deployments.json` and mirrors to `packages/oracle-dashboard/lib/deployments.json`
- `src/deploy-yield.ts` — deploys test yield tokens (`TestYieldFactory`, `TestYieldToken`,
  `YieldPocket`); writes `src/yield-deployments.json`
- `src/index.ts` — Commander entry point; all CLI commands
- `src/config.ts` — `DeployNetwork` union (`base | arbitrum | mainnet | sonic`), `VIEM_CHAINS`,
  `RPC_ENV_KEYS`, `RPC_ENV_CANDIDATES`
- `src/deployments.json` — per-network `oracleRegistry` address + oracle list (hand-maintained)
- `src/yield-deployments.json` — per-network yield token / pocket addresses (hand-maintained)

## Build and run commands

```bash
pnpm build              # tsc compile to dist/
pnpm cli <command>      # run any CLI command via ts-node
pnpm deploy:oracles     # deploy from deploy-input.json
pnpm format:fix         # prettier --write
```

There are no test scripts in this package.

## Setup

Create a `.env` in the repo root or in this package:

```env
BASE_RPC_URL=https://mainnet.base.org        # also accepts RPC_URL as fallback
ARBITRUM_RPC_URL=https://arb1.arbitrum.io/rpc
MAINNET_RPC_URL=https://eth.llamarpc.com
SONIC_RPC_URL=https://...
DEPLOYER_PRIV_KEY=0x...
PRIVATE_KEYS=0x_signer1,0x_signer2,...
WT_CLIENT=your_client_id
WT_SECRET=your_client_secret
WT_LOGIN=your_login
WT_PASSWORD=your_password
```

## Usage

### Deploy oracles

Edit `deploy-input.json` (array or single object), then:

```bash
pnpm deploy:oracles
```

### Run the oracle node daemon

```bash
# Monitor a single ticker; update when price deviates >= 1%
pnpm cli start SPXUX --deviation 1 --interval 60

# Monitor all tickers across all networks (omit ticker and --network)
pnpm cli start --deviation 0.5 --interval 120
```

The daemon polls every `--interval` seconds (default 60) and submits a batched Multicall3
transaction when price deviation meets or exceeds the threshold. There is no separate heartbeat
option.

### Manual update

```bash
pnpm cli update SPXUX --network base
```

### Registry and signer management

```bash
pnpm cli registry-set TICKER ASSET_ADDR ORACLE_ADDR --network base
pnpm cli add-signer <ORACLE_ADDR> <SIGNER_ADDR> --network base
pnpm cli set-threshold <ORACLE_ADDR> <THRESHOLD> --network base
```

### WisdomTree operations

```bash
pnpm cli wt-me
pnpm cli wt-tickers
pnpm cli wt-wallets [ticker]
pnpm cli wt-orders
pnpm cli wt-order <order_reference>
pnpm cli wt-accruals [organisation_guid]
pnpm cli wt-data WTSYX [YYYY-MM-DD]
pnpm cli wt-data-range CRDYX 2026-03-01 2026-03-09
pnpm cli wt-assets <ticker>
```

### Other commands

```bash
pnpm cli deploy-yield-system          # deploy TestYieldFactory + tokens
pnpm cli generate-deploy-input <tickers...>  # scaffold deploy-input.json
pnpm cli sync-config                  # push wallet data to packages/deployment/config/index.test.json
pnpm cli verify                       # verify contracts on Etherscan/Basescan/Arbiscan/Sonicscan
```

## Cross-package connections

**Consumes**

- `packages/rwa-oracles` — build artifacts (`RwaOracle.json`, `OracleRegistry.json`) are loaded at
  runtime from `../../rwa-oracles/out/`. The package must be built before deploying.

**Produces / shared state**

- `src/deployments.json` is mirrored verbatim to `packages/oracle-dashboard/lib/deployments.json` by
  `deploy.ts` on every deploy run. Both files must stay in sync; editing one by hand without the
  other will cause the dashboard to display stale data.
- `src/yield-deployments.json` is written by `deploy-yield.ts` and consumed only within this
  package.

**Agent gotchas**

- **Chain support is frozen at `base | arbitrum | mainnet | sonic`** in `src/config.ts`
  (`VIEM_CHAINS`, `RPC_ENV_KEYS`, `RPC_ENV_CANDIDATES`). Adding a new chain requires editing all
  three objects in that file and adding a `chainId` entry in `NETWORK_TO_CHAIN_ID` in `deploy.ts`.
  Hyperliquid was never added, so RWA oracle deploys cannot target it until this is done.
- `base` accepts `RPC_URL` as a legacy fallback in addition to `BASE_RPC_URL`; no other network has
  a fallback.
- `wt-wallets` and `wt-tickers` contain hard-coded ticker remappings (`CRDT` → `CRDYX`, `EPXC` →
  `WTPIX`) for the DataSpan API. Adding a new oracle whose on-chain ticker differs from the DataSpan
  ticker requires updating these remappings in `src/index.ts`.
- `sync-config` only processes `mainnet` (skips `base` and `arbitrum` with an explicit `continue`);
  this is intentional but non-obvious.

## GitBook reference

RWA Oracle contracts are documented at
[contracts/oracles](../../gitbook/contracts/oracles/reference/README.md). There is no dedicated
gitbook page for this CLI package.
