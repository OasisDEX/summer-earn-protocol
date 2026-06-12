# @summerfi/tenderly-utils

TypeScript utility library that wraps the Tenderly REST API and CLI for fork-based testing and
deployment workflows. It exposes functions to create and delete Tenderly forks via the v1 REST API
(`createFork`, `deleteFork`), spawn devnets by shelling out to the `tenderly devnet spawn-rpc` CLI
command (`spawnDevnet`), fund wallets with ETH or ERC-20 tokens on a fork (`setETHBalance`,
`setERC20TokenBalance`), inspect fork transactions (`getSimulations`,
`verifyTxReceiptStatusSuccess`, `getTxCount`), and transfer ownership of Summer proxy accounts
(`changeAccountOwner`). Uses `ethers` v6 for on-fork RPC calls and `axios` for REST requests.

## Key exports

- `createFork` / `deleteFork` — create or remove a Tenderly fork for `mainnet`, `optimism`,
  `arbitrum`, or `base`
- `spawnDevnet` — shell out to the Tenderly CLI to spawn a devnet RPC and fund a deployer address
- `setETHBalance` / `setERC20TokenBalance` — set wallet balances on a fork via `tenderly_setBalance`
  / `tenderly_setErc20Balance`
- `changeAccountOwner` — transfer ownership of a proxy via the hand-maintained `IAccountGuard` /
  `IAccountImplementation` ABIs in `src/abis.ts`
- `NetworkName`, `tokenAddresses`, `tokenBalances` — network type and hand-maintained token
  address/balance tables in `src/utils.ts` (internal only; not re-exported through `src/index.ts`)

## Build and test

```sh
# build
pnpm build          # tsc -b -v tsconfig.build.json

# unit tests (tests/ directory)
pnpm test           # jest tests/ --passWithNoTests

# end-to-end tests (e2e/ directory, requires live Tenderly credentials)
pnpm e2e            # jest e2e/

# watch mode
pnpm dev
```

## Required environment variables

The module throws at import time if any of these are unset:

| Variable              | Purpose               |
| --------------------- | --------------------- |
| `TENDERLY_USER`       | Tenderly account slug |
| `TENDERLY_PROJECT`    | Tenderly project slug |
| `TENDERLY_ACCESS_KEY` | Tenderly API key      |

`spawnDevnet` additionally requires `TENDERLY_TEMPLATE`, `TENDERLY_ACCOUNT`, and optionally
`DEPLOYER_ADDRESS` / `FUND_AMOUNT`.

## Cross-package connections

**Consumed by:** `packages/deployment`, `packages/gov-contracts`, `packages/core-contracts`,
`packages/math-utils`, `packages/percentage`, `packages/price-utils`, `packages/dutch-auction`,
`packages/intent-system` — all declare `"@summerfi/tenderly-utils": "workspace:*"` as a dependency,
used for fork-based test and deploy tooling.

**Consumes:** no other workspace packages. All token addresses (`src/utils.ts`) and proxy ABIs
(`src/abis.ts`) are hand-maintained and not derived from `packages/deployment` or any on-chain
source.

**Agent gotchas:**

- The module throws immediately on import if `TENDERLY_USER`, `TENDERLY_PROJECT`, or
  `TENDERLY_ACCESS_KEY` are unset. Any consuming package that imports this library in a context
  without those env vars will fail at module load, not at call time.
- `tokenAddresses` in `src/utils.ts` is a static lookup table maintained by hand. Adding support for
  a new network or token requires updating this file; there is no automatic sync with deployment
  configs.
- `IAccountGuardAbi` and `IAccountImplementationAbi` in `src/abis.ts` are also hand-maintained
  inline JSON. ABI changes in the corresponding contracts require a manual update here.
- `createFork` supports only four networks (`mainnet`, `optimism`, `arbitrum`, `base`); the
  network-id map is hardcoded in `src/tenderly.ts`.

No gitbook documentation section exists for this package.
