# @summerfi/summer-earn-rwa-app

Next.js application for the Summer.fi Earn Protocol **real-world-asset (RWA)**
experience — subscribing to, redeeming from, and monitoring permissioned RWA
vaults (e.g. institutional / round-based strategies). Connects to the protocol
contracts via Wagmi + Reown AppKit and reads data through TanStack Query.

## Stack

- Next.js (App Router) + React
- `@wagmi/core` / `@reown/appkit-adapter-wagmi` for wallet + chain interaction
- `@tanstack/react-query` for data fetching/caching

## Develop

```bash
pnpm dev          # start the dev server (http://localhost:3000)
pnpm build        # production build
pnpm start        # serve the production build
pnpm lint         # eslint
pnpm format:fix   # prettier
```

Run from the repo root with Turbo (`pnpm --filter @summerfi/summer-earn-rwa-app dev`)
or from this package directory.

> **Note:** this app pins a Next.js version with breaking changes from older
> releases — see `AGENTS.md` and consult `node_modules/next/dist/docs/` before
> changing framework-level code.

## Related

- On-chain RWA contracts: `@summerfi/earn-protocol-contracts`
  (`src/contracts/institutional/`, `src/contracts/rounds-vault/`) and
  `@summerfi/rwa-oracles`.
- Protocol documentation: the project GitBook space.
