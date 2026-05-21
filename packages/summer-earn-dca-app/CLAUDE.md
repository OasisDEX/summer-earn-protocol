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

Next.js 16 / React 19 / wagmi 3 / viem 2 / Reown AppKit. Single-chain (Base).
Reads from the [DCA subgraph](../summer-earn-dca-subgraph/CLAUDE.md) for
config + execution history; reads from RPC for live state via
`useHybridStrategy` (RPC wins on divergence).

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
  No codegen — repo convention.
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
