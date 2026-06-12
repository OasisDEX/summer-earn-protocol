# summer-earn-gov-alert-bot

A long-running Node.js service that polls on-chain governance events across mainnet, Base, Arbitrum,
and Sonic every 30 minutes, decodes governor and timelock logs against known ABIs and contract
addresses, and sends human-readable Telegram alerts via a Telegraf bot. It also exposes two Telegram
bot commands: `/check` for a manual dry-run poll, and `/tx <network> <hash>` to decode a specific
transaction on demand.

## Key modules

- `src/index.ts` — entry point; wires cron schedule, `Poller`, and Telegram bot listener
- `src/poller.ts` — `Poller` class; iterates `SupportedNetworks`, fetches logs for governor and
  timelock addresses, delegates to `EventProcessor`
- `src/config.ts` — `getGovernorAddresses()` and `getTimelockAddress()` read from
  `src/config/index.json` under keys `deployedContracts.gov.summerGovernor`,
  `deployedContracts.govV2.summerGovernor`, and `deployedContracts.gov.timelock`
- `src/config/rpc.ts` — `VIEM_CHAIN_ENTITIES` / `CHAIN_RPC_URLS` / `getPublicClient()`; fallback
  transport over public RPC lists for mainnet, Arbitrum, Base, Sonic, and Hyperliquid
- `src/services/validation.ts` — `SupportedNetworks` enum, calldata decoding (`decodeCalldata`,
  `decodeCrossChainCalldata`), address-to-contract-name resolution, cross-chain execution detection
- `src/state.ts` — persists the last-seen block per network to `state.json`

## Build and run

```
# sync deployment config from packages/deployment into src/config/
pnpm sync-config

# run in development (live reload)
pnpm dev

# run (production)
pnpm start

# build (esbuild)
pnpm build

# check formatting
pnpm format
```

Required environment variables (loaded from repo root `.env`): `TG_BOT_TOKEN`, `TG_CHAT_ID`.

## Cross-package connections

**Consumes:**

- `packages/deployment/config/index.json` — synced into `src/config/index.json` by
  `scripts/sync-config.js`; provides per-network `deployedContracts` and `tokens`
- `packages/deployment/ignition/deployments/chain-*/deployed_addresses.json` — synced into
  `src/config/deployed/<chain>.json` for address-to-name resolution
- `@summerfi/typescript-config` (dev) — shared TypeScript compiler config

**Not consumed by any other workspace package** (declared `private: true`; runs as a standalone
service).

**Agent gotchas:**

1. **`src/config/rpc.ts` is a near-duplicate of `gov-validator`'s `rpc.ts`** (same
   `VIEM_CHAIN_ENTITIES`/`CHAIN_RPC_URLS` pattern). Changes to one must be mirrored manually to the
   other — there is no shared library.

2. **`scripts/sync-config.js` `CHAIN_NAMES` map is missing Hyperliquid (chain ID 999).** The
   `VIEM_CHAIN_ENTITIES` in `rpc.ts` includes Hyperliquid, but sync-config will silently skip its
   `deployed_addresses.json`. Adding a new chain requires updating `CHAIN_NAMES` in sync-config,
   `SupportedNetworks` in `src/services/validation.ts`, `viemChains` in `src/config.ts`, and
   `VIEM_CHAIN_ENTITIES`/`CHAIN_RPC_URLS` in `src/config/rpc.ts`.

3. **Renamed config keys break the bot silently.** `getGovernorAddresses()` and
   `getTimelockAddress()` access hardcoded key paths (`deployedContracts.gov.summerGovernor`,
   `deployedContracts.govV2.summerGovernor`, `deployedContracts.gov.timelock`). If a governor or
   timelock is redeployed under a different key, the bot stops watching that address without error.

4. **`state.json` persists last-seen block numbers at the package root.** After a re-deploy or first
   run on a new chain, the bot defaults to the last 100 blocks if no prior state exists.

No matching section found in `gitbook/SUMMARY.md`.
