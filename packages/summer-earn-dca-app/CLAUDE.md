# DCA app — frontend

## Protocol

This file is meta-Claude memory. **Update it in the same commit as any
logic or design change here**, and add a line to the Sign-off block at the
bottom. The canonical protocol + DRY rules live in the
[contract CLAUDE.md](../core-contracts/src/contracts/DCA/CLAUDE.md); read it
first.

Siblings: [contract](../core-contracts/src/contracts/DCA/CLAUDE.md) ·
[keeper](../core-contracts/scripts/dca-keeper/CLAUDE.md) ·
[subgraph](../summer-earn-dca-subgraph/CLAUDE.md).

---

Next.js 16 / React 19 / wagmi 3 / viem 2 / Reown AppKit. Multichain — Base
(8453) + Ethereum mainnet (1). The active chain is **URL-encoded**: the
`/strategy` detail route carries it as a slug route segment
(`/strategy/base/123`, `/strategy/mainnet/123`; invalid slug → `notFound()`);
everywhere else (`/portfolio`, `/portfolio/[address]`, `/create`) it's a
`?chain=<slug>` query param defaulting to Base when absent/invalid. Slug map +
helpers live in `src/types/chain.ts` (`CHAIN_SLUGS`, `chainSlug`,
`chainIdFromSlug`, `resolveChainParam`, `DEFAULT_CHAIN_ID`); `useActiveChain()`
reads it back on the client, and a global `ChainSwitcher` in the topbar changes
it. **DCA manager addresses are the audited v5 deployments** (Base
`0x659d087B158008ce37FabF963Af329Ca59cE952a`, mainnet
`0xa0d3E060A43B980E12e688c0607c250F9F53985D`). Reads from the
[DCA subgraph](../summer-earn-dca-subgraph/CLAUDE.md) for config + execution
history (per-chain `CHAIN_DCA_SUBGRAPH_URLS`; mainnet slug is `summer-dca`);
reads from RPC for live state via `useHybridStrategy` (RPC wins on divergence).

## Files

- `src/abis/DCAStrategyManager.ts` — hand-regenerated from the Foundry
  artifact. **Wrap with `export const dcaStrategyManagerAbi = [...] as const`
  on one line** (multi-line `as const` is a TS parse error).
- `src/config/chains.ts` — RPC fallback list, block explorers, subgraph URL.
  All hardcoded, no env vars (only `NEXT_PUBLIC_WALLETCONNECT_ID` is
  env-driven, via `src/config/env.ts`).
- `src/lib/strategy/`
  - `commitment.ts` — `keccak256(abi.encode(config))` mirror of the contract.
    **Tuple type must NOT include `strategyId`.**
  - `encode.ts` — `toStrategyConfigStruct(subgraphStrategy)` rebuilds the
    on-chain tuple from a subgraph row; `buildCreateTuple(input)` builds the
    tuple for `createStrategy`.
- `src/lib/subgraph/{client,queries,types}.ts` — hand-written GraphQL docs +
  TS types mirroring [`schema.graphql`](../summer-earn-dca-subgraph/schema.graphql).
  No codegen — repo convention. Includes the `PRICE_HISTORY` query against
  the `PriceFeed`/`PriceRound` entities the subgraph indexes from Chainlink
  proxies.
- `src/lib/prices/` — abstracted historical-price layer.
  - `types.ts` — `PriceSeries`, `PricePoint`, `PriceFeedSource`, `PriceRange`.
  - `chainlinkSubgraph.ts` — **primary** source. Queries `priceRounds` from
    the DCA subgraph, resolves `token → feed` via `lookupFeedForAsset` and
    detects gaps using `heartbeats.ts`. Faithful to what the keeper sees.
  - `defillama.ts` — **fallback**. Free public `coins.llama.fi/chart/base:0x...`.
    Sets `basis: 'off-chain-aggregate'` so the chart can warn that guardrail
    lines are evaluated against a different oracle.
  - `composite.ts` — cascade on null/throw, partial-merge when primary
    covers <75% of the requested range.
  - `index.ts` — singleton `getPriceClient()`; **server-only**.
- `src/app/api/prices/[chainId]/[token]/route.ts` — cached GET handler.
  `'use cache'` + `cacheLife({ stale: 60, revalidate: 300, expire: 86_400 })`
  + `cacheTag('price', 'price:{chainId}', 'price:{chainId}:{token}',
  'price:{chainId}:{token}:{range}')`. **Only place external HTTP happens.**
  Opt-in via `experimental.useCache: true` in `next.config.mjs`.
- `src/app/api/prices/revalidate/route.ts` — `POST` guarded by
  `Bearer $PRICE_REVALIDATE_SECRET`; calls `updateTag` to drop edge cache on
  Goldsky webhook delivery (so an executed strategy refreshes inside 5 min
  instead of the 300s revalidate window).
- `src/hooks/`
  - `useDcaStrategyActions.ts` — write paths
    (`create/edit/pause/resume/cancel`). Every contract write goes through
    `useTxToast`.
  - `useTxToast.ts` — sonner lifecycle around `useWriteContract` +
    `useWaitForTransactionReceipt`. Decodes named reverts
    (`DuplicateStrategy`, `CommitmentMismatch`, `StrategyNotActive`,
    `UnauthorizedAccess`) into friendly toasts via
    `FRIENDLY_REVERT_LABELS`.
  - `useHybridStrategy.ts` — merges subgraph row + RPC `strategyStates(id)`.
  - `usePermit2Approval.ts` — drives the 2-step approval (ERC20 → Permit2,
    then Permit2 → manager).
  - `useTokenPriceHistory.ts` / `useTokenSparkline.ts` /
    `useStrategyChartData.ts` — TanStack Query wrappers on the price route +
    composer that merges `useHybridStrategy` with two price-history fetches
    (in & out asset) and execution dots. Query key
    `['dca','price-history', chainId, token, range, feed]`,
    `staleTime: 300_000` (matches the edge revalidate).
- `src/components/charts/{Sparkline,MiniChart,LineChart}.tsx` — chart
  primitives. **`LineChart` is gap-aware**: it breaks the path at each
  `gaps[][]` region instead of drawing straight-line lies. Draggable
  ceiling/floor handles call local setters on the Detail page; the chart
  never invalidates the price cache.
- `src/components/shell/{Sidebar,Topbar}.tsx` + `src/app/layout.tsx` — the
  summer.fi design shell (sidebar + topbar + `.bg-glow`/`.bg-grid` ambient
  layers). Tokens live in `src/app/globals.css` (as CSS vars) and
  `tailwind.config.js` (as alias names). Geist + Geist Mono via
  `@fontsource/geist*`.
- `src/components/CreateStrategyForm.tsx` — pre-flight duplicate check
  via `activeCommitments(commitment)` view; blocks submit if true.
- `src/types/strategy.ts` — `StrategyConfigTuple` (no `strategyId`),
  `StrategyStatus` enum.

## Invariants

- **`StrategyConfigTuple` field order is binding.** It must exactly match
  `IDCAStrategyManager.StrategyConfig` (see
  [contract CLAUDE.md](../core-contracts/src/contracts/DCA/CLAUDE.md)). A
  drift here surfaces as a `CommitmentMismatch` revert on every action that
  re-passes the config (edit/resume/execute), or as a silent duplicate-check
  miss on create.
- **`strategyId` is passed separately** to `editStrategy`,
  `resumeStrategy`, `pauseStrategy`, `cancelStrategy`. It is NOT inside the
  hashed payload.
- **Owner verification is stateless on-chain.** When calling pause/cancel/
  resume the FE must pass the *current* config (use
  `toStrategyConfigStruct(subgraphStrategy)`), otherwise the contract reverts
  `CommitmentMismatch` before checking `msg.sender`.
- **For `editStrategy`, both `oldConfig` and `newConfig` are required.** Pull
  `oldConfig` from the subgraph row at submit time.
- **TS strictness.** `pnpm exec tsc --noEmit` + `pnpm lint` must be clean
  before push. The ABI is `as const`, so wagmi infers the exact arg/return
  types — typing drift catches contract/FE divergence at compile time.
- **Price-source contract.** All sources return `null` to mean "I don't know
  this token"; throws are reserved for transport/parse errors. The composite
  client cascades on `null` and merges partial primary responses
  (>25% gap fraction) with the fallback. Don't sprinkle `try/catch` inside
  source impls — let throws propagate so the composite can pick a backup.
- **`maxPrice` / `minPrice` are the 1e18-scaled out/in execution-price
  ratio.** The on-chain check uses
  `executionPrice = outPrice * 10**inOracleDec * 1e18
                  / (inPrice * 10**outOracleDec)` and compares it against
  the configured bounds. The form scales user input via `parseUnits(_, 18)`;
  `useStrategyChartData` divides the stored bounds by `1e18` for display and
  builds a *ratio* price line (`outPriceUSD / inPriceUSD` pointwise) so the
  chart line and the guardrails live in the same numeric space.
- **Guardrail-line basis.** Dashed `MAX`/`MIN` lines on the LineChart and
  the chart line itself are in `inAsset per outAsset` units. When either
  underlying series is from DeFiLlama (`basis: 'off-chain-aggregate'`), the
  Detail header surfaces an "off-chain pricing" pill so the user knows the
  guardrails (evaluated against Chainlink on-chain) and the chart aren't
  strictly comparable.
- **`cacheComponents: true` is required.** It's the top-level Next 16 stable
  flag in `next.config.mjs`. Anything async in a page must either be inside a
  `'use cache'` function or under a `<Suspense>`, or the build fails with
  "Uncached data was accessed outside of <Suspense>". `await params` counts —
  defer it into the loader inside the Suspense, don't await it at the page
  default export. `Sidebar` (uses `usePathname`/`useAccount`/`useBalance`) is
  Suspense-wrapped in `src/app/layout.tsx` with a `SidebarSkeleton` fallback;
  the layout itself is `'use cache'`.

## When the contract changes

1. Regenerate `src/abis/DCAStrategyManager.ts` from the Foundry artifact:
   ```
   {
     printf 'export const dcaStrategyManagerAbi = '
     jq '.abi' ../core-contracts/out/DCAStrategyManager.sol/DCAStrategyManager.json
     printf ' as const\n'
   } > src/abis/DCAStrategyManager.ts
   # Then collapse the final '] as const' onto one line — TS won't accept '\n as const'.
   ```
2. Update `src/types/strategy.ts` if the struct shape changed.
3. Update `src/lib/strategy/{commitment,encode}.ts` in lockstep.
4. Update `src/hooks/useDcaStrategyActions.ts` if a function signature
   changed (new arg, reorder, etc.).
5. Add the new revert name to `FRIENDLY_REVERT_LABELS` in
   `src/hooks/useTxToast.ts` if there's a new user-facing error.

## Quick commands

```
pnpm --filter @summerfi/summer-earn-dca-app dev
pnpm --filter @summerfi/summer-earn-dca-app exec tsc --noEmit
pnpm --filter @summerfi/summer-earn-dca-app lint
```

## Deployment

AWS Amplify, `WEB_COMPUTE` platform. Provisioned by
[`/infrastructure/main.tf`](../../infrastructure/main.tf) (`module "dca_app"`).
Auto-build on `main`; `pr*` branches get PR previews.

## Sign-off

<!-- One line per material change. Most recent on top.
Format: YYYY-MM-DD — author — one-sentence summary. -->

- 2026-06-30 — claude — fix the Amplify `next build` (cacheComponents prerender). `ChainSwitcher` + the breadcrumb/CTA `ChainAwareLink` read request-time location (`usePathname`/`useSearchParams`) and were rendered in `Topbar` **outside** any `<Suspense>`, so a full `next build` aborted prerendering `/portfolio/[address]` with "Uncached data was accessed outside of <Suspense>" (only fires in a production build — `tsc`/`next dev` pass). Wrapped the crumb links and the `ChainSwitcher`+`actions` cluster inside `Topbar` in `<Suspense>` (fallbacks: plain label / null). `next build` now green — all four app routes are ◐ Partial Prerender. **Rule:** any client component reading `usePathname`/`useSearchParams` (chain-aware nav) must sit under a `<Suspense>`; `Topbar` now does this internally, `Sidebar` is wrapped by `layout.tsx`. The latent break landed with `ChainSwitcher` in #880; this covers it + `ChainAwareLink`.
- 2026-06-30 — claude — CodeRabbit follow-up (PR #880): preserve the active chain on cross-page nav. New client `ChainAwareLink` (`src/components/shell/ChainAwareLink.tsx`) appends `?chain=<active-slug>` to a relative href unless it already pins a chain or targets a `/strategy/<slug>/` route; now backs the `Topbar` breadcrumb links and the `/portfolio` + `/portfolio/[address]` "New strategy" CTAs, and the create-page breadcrumb was retargeted `/` → `/portfolio`. Fixes those links dropping users to the default-Base flow. Chain is read client-side via `useActiveChain` (same as `ChainSwitcher`), so no `searchParams` access is added to the cacheComponents-gated server pages. `tsc --noEmit` + lint clean.
- 2026-06-30 — claude — v5 address swap (bd aphelion-app-4z5 done): `DCA_STRATEGY_MANAGER_ADDRESSES` now points at the audited v5 deploys (Base `0x659d…952a`, mainnet `0xa0d3…985D`), superseding the interim-v4 placeholders from the multichain commit below. Config/UX only; `tsc --noEmit` + lint clean.
- 2026-06-30 — claude — multichain (Base + Ethereum mainnet) refactor with URL-encoded chain selection: `/strategy/[chain]/[id]` slug route segment (moved from `/strategy/[id]`, invalid slug → `notFound()`) and `?chain=<slug>` query param on `/portfolio`, `/portfolio/[address]`, `/create` (defaults to Base). Added `src/types/chain.ts` slug helpers (`CHAIN_SLUGS`/`chainSlug`/`chainIdFromSlug`/`resolveChainParam`/`DEFAULT_CHAIN_ID`), the `useActiveChain()` hook, and a global topbar `ChainSwitcher`. Filled `[mainnet.id]` into every `config/chains.ts` + `config/addresses.ts` map (mainnet subgraph slug `summer-dca`, mainnet Chainlink feeds + token addresses) and registered base+mainnet networks/transports in `providers.tsx`. **Both DCA manager addresses are interim v4 pending the v5 swap (bd aphelion-app-4z5).** cacheComponents: dropped `'use cache'` from `create`/`portfolio` pages (now read `searchParams`) and deferred the `await searchParams` read into `<Suspense>`-wrapped loaders; `/portfolio/[address]` + `/strategy/[chain]/[id]` loaders read the chain inside their existing Suspense'd loaders — never `await params`/`searchParams` at the page body. `tsc --noEmit` + lint clean.
- 2026-06-30 — claude — broad app↔contract drift audit against the #875 contract: `StrategyConfigTuple`/`commitment.ts`/`encode.ts`/`types`, the `as const` ABI, write-call signatures, and `subgraph/{queries,types}.ts` all verified already in sync (no change). The only drift was `FRIENDLY_REVERT_LABELS` in `useTxToast.ts`. Added the app-reachable (create/edit/pause/resume/cancel) errors that lacked labels: `TradeAmountTooLarge` (supersedes the 2026-06-29 "did NOT add" note), `ZeroTradeAmount`, `ZeroMaxTrades`, `InvalidSlippage`, `InvalidOwner`, `SameAsset`, `IntervalTooShort`, `IntervalTooLong`, `InvalidFeedAddress`, `UnauthorizedOwner`, `InactiveFleetCommander`. Also added the `depositAndCreate`/keeper-execution errors (`ZeroDeposit`, `DepositSharesBelowMin`, `PriceAboveCeiling`, `PriceBelowFloor`, `ExecutionWindowNotReached`, `SwapOutputBelowMinOut`) for a complete error dictionary — these are NOT reachable via the app's current actions, consistent with the existing keeper-only `ZeroExpectedOutShares`/Permit2 entries (Codex review flagged the dead entries; kept + documented honestly rather than removed). UX-only (toast text); `tsc --noEmit` clean. The DCA subgraph was audited in the same pass (event signatures, 14-field tuple + nested feeds, ExecutionCompleted params, schema, ABI, status enum, mappings) and confirmed byte-for-byte in sync — no subgraph change.
- 2026-06-29 — claude — ABI sync with core-contracts audit follow-ups (PR #875): added the new `TradeAmountTooLarge` error to `src/abis/DCAStrategyManager.ts` (contract F11 rejects `tradeAmount > uint160` max on create/edit). No struct/signature change. Did NOT add a `FRIENDLY_REVERT_LABELS` entry — the revert is unreachable via the form (amount is bounded well below uint160 max).
- 2026-06-19 — claude — lockstep with contract CL-1: `StrategyConfig.inAssetFeed`/`outAssetFeed` are now `ChainlinkFeed { address feed; uint256 maxStaleness }` tuples (was flat `address`). Regenerated `src/abis/DCAStrategyManager.ts`; added `ChainlinkFeedTuple` + nested `StrategyConfigTuple` in `types/strategy.ts`; `commitment.ts` tuple-type nests the two feeds; `encode.ts` builds `{feed, maxStaleness}` (subgraph staleness for edits, `0` default for create); `subgraph/{types,queries}.ts` gained `in/outAssetFeedStaleness`. `tsc --noEmit` clean. Commitment-hash break — deploy with the matching contract + re-indexed subgraph.
- 2026-05-28 — claude — ABI sync after contract security fixes. Regenerated `src/abis/DCAStrategyManager.ts`; subgraph types/queries renamed `Execution.amountIn`/`amountOut` → `inAssets`/`outAssets` (added `inShares`/`outShares`) so the FE's existing asset-decimal formatting is now semantically correct. Added 6 new revert labels to `FRIENDLY_REVERT_LABELS` (InAssetVaultMismatch, OutAssetVaultMismatch, ZeroExpectedOutShares, InvalidPriceBounds, Permit2AllowanceInsufficient, Permit2ExpirationTooEarly). `CreateStrategyForm` gained pre-flight guards: `minPrice > maxPrice` is blocked locally, and `sourceVault.asset()` / `targetVault.asset()` are re-read on-chain and compared against the chosen `inAsset`/`outAsset`. Subgraph must be re-indexed before the new asset fields appear.
- 2026-05-21 — claude — migrated to Next 16 stable Partial Prerendering:
  `next.config.mjs` swapped `experimental.useCache` → `cacheComponents: true`.
  Root `layout.tsx` and `/portfolio`, `/create` page shells are now
  `'use cache'`. `Sidebar` (uses `usePathname`/`useAccount`/`useBalance`)
  lives inside `<Suspense fallback={<SidebarSkeleton />}>` so the cached
  shell can prerender around it. `/portfolio/[address]` and `/strategy/[id]`
  defer `await params` + `await loadPortfolio` / `await loadStrategyDetail`
  into Suspense'd loader server components with new `PortfolioSkeleton` /
  `StrategyDetailSkeleton` fallbacks — the routes now build as ◐ Partial
  Prerender. Data-layer caching (`'use cache'` + `cacheTag` inside
  `lib/server/*` and `lib/prices/cached`) was already in place.
- 2026-05-21 — claude — `maxPrice` / `minPrice` are now bounds on the
  1e18-scaled out/in execution-price ratio (out-asset denominated in
  in-asset). `CreateStrategyForm` uses `parseUnits(_, 18)` and the labels
  switched to "Max/Min `{out}` price (`{in}` per `{out}`)". `LineChart`
  takes a `formatValue` prop (no hardcoded `$`); `useStrategyChartData`
  builds a pointwise `outPrice/inPrice` ratio series so the chart line and
  the guardrails share a unit. Minimum interval lowered from 7 days to 1
  day; presets now include 1d / 3d / 7d / 14d / 28d.
- 2026-05-21 — claude — summer.fi rebuild: ported design tokens into
  `globals.css`+`tailwind.config.js`, new sidebar+topbar shell, rebuilt
  Portfolio dashboard (KPI tiles + filter + card grid), restyled Detail page
  around the new chart card, gap-aware draggable-guardrail `LineChart`,
  status-pill executions table.
- 2026-05-21 — claude — added `src/lib/prices/` abstraction
  (Chainlink-subgraph primary + DeFiLlama fallback + composite cascade),
  `src/app/api/prices/[chainId]/[token]/route.ts` with
  `'use cache'` + `cacheLife` + `cacheTag`, a revalidate endpoint, and
  `useTokenPriceHistory`/`useTokenSparkline`/`useStrategyChartData` hooks.
  Subgraph counterpart adds `PriceFeed`/`PriceRound` with bootstrap
  USDC/ETH backfill + dynamic `ChainlinkAggregator` template registered
  from `handleStrategyCreated`/`handleStrategyEdited`.
- 2026-05-21 — claude — added pre-flight `activeCommitments` read in
  `CreateStrategyForm` to block duplicate submits before the wallet prompt;
  `useTxToast` decodes `DuplicateStrategy` / `CommitmentMismatch` /
  `StrategyNotActive` / `UnauthorizedAccess` reverts to friendly labels.
- 2026-05-21 — claude — `editStrategy(strategyId, oldConfig, newConfig)` —
  call sites now pull `oldConfig` from the subgraph row;
  `pauseStrategy` / `cancelStrategy` / `resumeStrategy` also take the
  current config tuple.
- 2026-05-21 — claude — `StrategyConfigTuple` dropped `strategyId` (moved
  outside the on-chain struct); `commitment.ts` and `encode.ts` updated in
  lockstep. ABI regenerated with `[…] as const` on one line (multi-line
  `as const` is a TS parse error).
- 2026-05-21 — claude — provisioned via `module "dca_app"` in
  `infrastructure/main.tf`.
- 2026-05-21 — claude — config moved fully into the package; no env vars
  for RPC URL or subgraph URL (hardcoded). Only
  `NEXT_PUBLIC_WALLETCONNECT_ID` is env-driven.
- 2026-05-21 — claude — initial CLAUDE.md.
