# summer-earn-auctions-frontend

Next.js 16 (React 19) app that displays active and finished Raft dutch auctions across Ethereum
mainnet, Base, Arbitrum, and Sonic. It queries per-chain subgraph endpoints for auction data,
renders recharts price-decay curves, and lets users connect a wallet (via wagmi + Reown AppKit) to
purchase auction lots.

## Key source files

| Path                                 | Role                                                                                                                                            |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `src/lib/config.ts`                  | `CHAIN_CONFIGS` map — subgraph endpoints, Raft contract addresses, and RPC URL resolution per chain                                             |
| `src/lib/types.ts`                   | `ChainConfig` and shared auction types                                                                                                          |
| `src/components/AuctionPurchase.tsx` | On-chain purchase flow                                                                                                                          |
| `src/app/page.tsx`                   | Active auctions list                                                                                                                            |
| `src/app/finished/`                  | Finished auctions view                                                                                                                          |
| `src/app/apr-charts/`                | APR / price-decay chart pages (stub — directory exists with empty `components/` and `context/` subdirectories but contains no source files yet) |

## Build and dev commands

All commands are run from the package root or via turbo from the repo root.

```
pnpm dev          # next dev
pnpm build        # next build
pnpm lint         # eslint .
pnpm lint:fix     # eslint . --fix
pnpm format       # prettier check
pnpm format:fix   # prettier write (run after every edit)
```

## Environment variables

Each chain needs an RPC URL. The app reads `<CHAIN>_RPC_URL` server-side and
`NEXT_PUBLIC_<CHAIN>_RPC_URL` client-side. Without them a console warning fires and an Infura
placeholder URL is used as fallback.

```
MAINNET_RPC_URL / NEXT_PUBLIC_MAINNET_RPC_URL
BASE_RPC_URL    / NEXT_PUBLIC_BASE_RPC_URL
ARBITRUM_RPC_URL / NEXT_PUBLIC_ARBITRUM_RPC_URL
SONIC_RPC_URL   / NEXT_PUBLIC_SONIC_RPC_URL
```

## Cross-package connections

**Consumes:**

- `@summerfi/eslint-config`, `@summerfi/jest-config`, `@summerfi/typescript-config` (workspace dev
  tooling)
- Staging subgraph endpoints hardcoded in `src/lib/config.ts`
  (`https://subgraph.staging.oasisapp.dev/summer-auctions[-chain]`)

**Consumed by:** nothing — this is a leaf app.

**Agent gotchas:**

1. **Raft addresses are hand-copied.** There is no sync script. Mainnet, Base, and Arbitrum all
   share `0xD1Bccfd8B32A5052a6873259c204CBA85510BC6E`; Sonic uses
   `0x6E6b9CB3BA753337ab91BC5A1dbAD83b8F05e204`. When a new deployment changes a Raft address,
   `src/lib/config.ts` must be updated manually.

2. **Adding a new chain** requires a single manual edit: add a `CHAIN_CONFIGS` entry in
   `src/lib/config.ts` with `subgraphEndpoint`, `raftAddress`, and the new `<CHAIN>_RPC_URL` env
   var. No other files in this package need changing.

3. **Sonic copy-paste bug:** the Sonic entry passes `'Optimism'` as the `chainName` argument to
   `validateRpcUrl`, so the missing-RPC warning message incorrectly names the chain "Optimism". This
   affects only the warning text, not runtime behavior.

## Related gitbook docs

Contract-level reference (DutchAuctionManager, DutchAuctionLibrary, etc.):
[`gitbook/contracts/dutch-auction/reference/`](../../gitbook/contracts/dutch-auction/reference/README.md).
There is no dedicated gitbook page for this frontend package.
