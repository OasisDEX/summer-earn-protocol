# Domino (`@halaprix/domino`) Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace hand-rolled sequential `client.multicall` pipelines in `summer-earn-interface` server code with `@halaprix/domino` v1.3.0 task graphs, with byte-identical JSON responses and every changed unit covered by tests written first.

**Architecture:** A `src/lib/domino/` layer holds an executor factory plus per-domain *task builder* functions (`defineTask`) and pure *assembly* functions that turn resolved refs into the existing payload shapes. Because `defineTask` builders run **once, synchronously**, dynamic-length fan-out (e.g. one call per ark returned by `getActiveArks`) is done in two phases: a small "index" task run first, then one task instance per discovered item, all executed in a single `runSettled` batch. Routes become thin wrappers (params, cache, `NextResponse`) around exported, executor-injectable core functions — the executor injection is the test seam.

**Tech Stack:** `@halaprix/domino@1.3.0` (exact pin), viem 2.x, Next.js 16 route handlers, jest 29 + ts-jest.

## Validation notes (changes vs. the v1 plan)

These are corrections discovered by reading domino 1.3.0's published `index.d.ts` and the current source — do not revert to the v1 design:

1. **No single-graph dynamic fan-out.** `defineTask(build)` runs `build` exactly once, synchronously; you cannot mint `t.call`s per element of a `Ref<array>`. Harbor → per-ark reads therefore needs a two-phase design (index task, then N per-item tasks). What *does* work inside one graph: a `Ref` feeding another call's `args` (`convertToAssets(sharesRef)`) or `target` (`balanceOf` on a pool address derived from `details()`, or on an `asset()` result).
2. **Tasks are single-use.** Re-running a `defineTask` instance throws `DominoTaskReuseError`. All task modules export `build*Task()` factory functions, never task instances.
3. **`t.call` accepts only `view`/`pure` functions.** All calls we migrate are views — but if an ABI is not const-asserted, type inference degrades to `string`/`unknown`; assembly functions therefore cast results explicitly (same style as the current code).
4. **`MultichainResolver` is dropped from scope.** `runAll` requires a homogeneous task type per plan and can't express our per-chain *sequential* stages (fleets → arks per fleet). `getAllArksOverview` keeps its existing `Promise.all`-over-chains orchestration and simply benefits from the refactored per-chain functions. (Future work if desired.)
5. **`fleetDetailTask` was named in v1's tree but never given an implementation phase** — it is Task 8/9 here.
6. **Error-message parity strategy:** every `t.call` is `optional: true`; required-ness is enforced in pure assembly functions that throw `ArksOverviewError` with the *exact* legacy messages/status codes. This avoids depending on domino's internal rejection payloads and makes every failure branch unit-testable.
7. **`Presets.throughput` enables `adaptiveBatching: true`**, whose own docs warn it can amplify HTTP 429 rate-limit failures by up to `2N−1` retries. We centralize options in one `DEFAULT_RUN_OPTIONS` constant so this can be tuned in one place if 429s appear.
8. **Multicall3 on HyperEVM:** `Eip1193Executor` falls back to *deployless* multicall on chains missing from its deployment table, so the tipjar route's manual `multicall3` chain-entity injection is no longer needed.

## Global Constraints

- Dependency pin: `"@halaprix/domino": "1.3.0"` (exact, no caret).
- **100% JSON response-schema parity** for `/api/arks-overview` data (`getAllArksOverview`), `/api/tipjar`, and `/api/fleets/[chainId]/[address]` — bigints serialized via `.toString()`, same keys, same conditional-key behavior, same fallback defaults (`'Unknown fleet'`, `18`, `''`, `'0'`), same error strings and HTTP statuses.
- No UI/frontend changes; exported names `getAllArksOverview`, `getFleetsForChain`, `getArksForFleet`, `computeBufferSharePct`, `getArkStatus`, `parseArkDetails`, `ArksOverviewError` and all exported types keep their signatures (new trailing optional `executor` params are allowed).
- The hard-coded extra Base fleet `0x29f13a877F3d1A14AC0B15B07536D4423b35E198` (chain `8453`) must be preserved.
- File naming: kebab-case (`arks-overview-task.ts`, matching the package's existing style), not v1's camelCase.
- Run all commands from `packages/summer-earn-interface`. Test command: `pnpm test -- <path>`.
- Run `pnpm format:fix` after every task's edits (repo rule).
- **No automated git commits** (user constraint for this integration) — task steps end at "tests pass + format", not at a commit. Note this deliberately overrides the usual frequent-commit convention; the human integrates the final diff.

## File Structure

```
packages/summer-earn-interface/src/lib/domino/
├── executor.ts                       # createExecutorForChain + DEFAULT_RUN_OPTIONS
├── testing/
│   └── mock-executor.ts              # MockStepExecutor (jest seam, no RPC)
└── tasks/
    ├── arks-overview-task.ts         # index/fleet-summary/per-ark task builders + assembly
    ├── tipjar-task.ts                # tipjar task builders + assembly + getTipjarPayload
    └── fleet-detail-task.ts          # fleet-detail task builder + assembly + getFleetDetailPayload

Modified:
├── src/lib/arks-overview.ts          # getFleetsForChain / getArksForFleet re-implemented on domino
├── src/app/api/tipjar/route.ts       # thin wrapper around getTipjarPayload
└── src/app/api/fleets/[chainId]/[address]/route.ts  # thin wrapper around getFleetDetailPayload

Tests:
├── src/lib/domino/testing/mock-executor.test.ts
├── src/lib/domino/tasks/arks-overview-task.test.ts
├── src/lib/domino/tasks/tipjar-task.test.ts
├── src/lib/domino/tasks/fleet-detail-task.test.ts
└── src/lib/arks-overview.test.ts     # existing — extended with executor-injected coverage
```

Note on import cycles: `tasks/arks-overview-task.ts` imports pure helpers/types from `@/lib/arks-overview`, which imports the task builders back. Both directions are used only inside function bodies (no top-level evaluation), which is safe under ts-jest/Next bundling. Do not "fix" this by moving `ArkOverview`/`parseArkDetails` — UI code imports them from `@/lib/arks-overview`.

---

### Task 1: Dependency + MockStepExecutor test seam

**Files:**
- Modify: `package.json` (dependencies)
- Create: `src/lib/domino/testing/mock-executor.ts`
- Test: `src/lib/domino/testing/mock-executor.test.ts`

**Interfaces:**
- Produces: `MockStepExecutor` (implements domino `StepExecutor`; constructor takes `Record<string, MockValue>` keyed by `callKey(target, functionName)`); `callKey(target: string, functionName: string): string` (lowercased `"<target>.<functionName>"`); `FAIL` sentinel symbol to mock a per-call failure. Every later test consumes these.

- [ ] **Step 1: Install the dependency**

```bash
pnpm add @halaprix/domino@1.3.0 --save-exact
```

Expected: `package.json` gains `"@halaprix/domino": "1.3.0"`.

- [ ] **Step 2: Write the failing test**

Create `src/lib/domino/testing/mock-executor.test.ts`:

```ts
import { defineTask, runSettled } from '@halaprix/domino'

import { callKey, FAIL, MockStepExecutor } from './mock-executor'

const TOKEN = '0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' as const
const erc20Abi = [
  {
    type: 'function',
    name: 'decimals',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint8' }],
  },
  {
    type: 'function',
    name: 'balanceOf',
    stateMutability: 'view',
    inputs: [{ name: 'owner', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const

describe('MockStepExecutor', () => {
  it('resolves a defineTask graph from the handler map', async () => {
    const executor = new MockStepExecutor({
      [callKey(TOKEN, 'decimals')]: 6,
      [callKey(TOKEN, 'balanceOf')]: (args) => (args?.[0] === '0x01' ? 42n : 0n),
    })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals' }),
      balance: t.call({
        target: TOKEN,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: ['0x01' as `0x${string}`],
      }),
    }))
    const [result] = await runSettled(executor, [task])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ decimals: 6, balance: 42n })
    }
  })

  it('fails calls mapped to FAIL and calls with no handler', async () => {
    const executor = new MockStepExecutor({ [callKey(TOKEN, 'decimals')]: FAIL })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals', optional: true }),
      balance: t.call({
        target: TOKEN,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: ['0x01' as `0x${string}`],
        optional: true,
      }),
    }))
    const [result] = await runSettled(executor, [task])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ decimals: undefined, balance: undefined })
    }
  })

  it('records dispatched batches for round-trip assertions', async () => {
    const executor = new MockStepExecutor({ [callKey(TOKEN, 'decimals')]: 6 })
    const task = defineTask((t) => ({
      decimals: t.call({ target: TOKEN, abi: erc20Abi, functionName: 'decimals' }),
    }))
    await runSettled(executor, [task])
    expect(executor.batches).toHaveLength(1)
    expect(executor.batches[0][0].functionName).toBe('decimals')
  })
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `pnpm test -- src/lib/domino/testing/mock-executor.test.ts`
Expected: FAIL — `Cannot find module './mock-executor'`.

- [ ] **Step 4: Write the implementation**

Create `src/lib/domino/testing/mock-executor.ts`:

```ts
import type { RawResult, StepCall, StepExecutor } from '@halaprix/domino'

/** Sentinel: map a call key to FAIL to make that call return a failure result. */
export const FAIL = Symbol('domino-mock-fail')

/** Static value, FAIL, or an args-dependent resolver. */
export type MockValue = unknown | ((args: readonly unknown[] | undefined) => unknown)

export function callKey(target: string, functionName: string): string {
  return `${target.toLowerCase()}.${functionName}`
}

/**
 * In-memory StepExecutor for tests. Calls resolve from the handler map by
 * `callKey(target, functionName)`; unmapped calls fail (so a test that
 * forgets a handler surfaces as a visible failure, not a hang).
 */
export class MockStepExecutor implements StepExecutor {
  readonly batches: StepCall[][] = []

  constructor(private readonly handlers: Record<string, MockValue>) {}

  async executeMulticall(calls: StepCall[]): Promise<RawResult[]> {
    this.batches.push(calls)
    return calls.map((call) => {
      const key = callKey(call.target, call.functionName)
      if (!(key in this.handlers)) {
        return { status: 'failure', error: new Error(`MockStepExecutor: no handler for ${key}`) }
      }
      const handler = this.handlers[key]
      const value =
        typeof handler === 'function'
          ? (handler as (args: readonly unknown[] | undefined) => unknown)(call.args)
          : handler
      if (value === FAIL) {
        return { status: 'failure', error: new Error(`MockStepExecutor: mocked failure for ${key}`) }
      }
      return { status: 'success', value }
    })
  }

  async getBlockNumber(): Promise<bigint> {
    return 1n
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `pnpm test -- src/lib/domino/testing/mock-executor.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Format**

Run: `pnpm format:fix`

---

### Task 2: Executor factory (`executor.ts`)

**Files:**
- Create: `src/lib/domino/executor.ts`
- Test: covered indirectly (pure config constant asserted in Task 3's test file is unnecessary — this module is a 15-line factory; its behavior is exercised by every route smoke run). One direct unit test below keeps the constant honest.
- Test: `src/lib/domino/executor.test.ts`

**Interfaces:**
- Produces: `createExecutorForChain(chainId: string): StepExecutor` (throws plain `Error` for unknown chains — callers do their own 400 guard first, matching current behavior); `DEFAULT_RUN_OPTIONS: BatchOptions`.

- [ ] **Step 1: Write the failing test**

Create `src/lib/domino/executor.test.ts`:

```ts
import { DEFAULT_RUN_OPTIONS, createExecutorForChain } from './executor'

describe('executor', () => {
  it('DEFAULT_RUN_OPTIONS spreads Presets.throughput', () => {
    expect(DEFAULT_RUN_OPTIONS).toEqual({
      maxConcurrentBatches: 5,
      adaptiveBatching: true,
      dedupe: true,
    })
  })

  it('throws for an unsupported chainId', () => {
    expect(() => createExecutorForChain('999999')).toThrow(/999999/)
  })

  it('returns a StepExecutor for a supported chain', () => {
    const executor = createExecutorForChain('8453')
    expect(typeof executor.executeMulticall).toBe('function')
    expect(typeof executor.getBlockNumber).toBe('function')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test -- src/lib/domino/executor.test.ts`
Expected: FAIL — `Cannot find module './executor'`.

- [ ] **Step 3: Write the implementation**

Create `src/lib/domino/executor.ts`:

```ts
import { Eip1193Executor, Presets, type BatchOptions, type StepExecutor } from '@halaprix/domino'
import { createPublicClient } from 'viem'

import { CHAIN_RPC_URLS, createRpcTransport, VIEM_CHAIN_ENTITIES } from '@/config/chains'

/**
 * Single tuning point for every domino run in this app.
 * NOTE: adaptiveBatching retries can amplify RPC 429s (up to 2N-1 extra calls
 * per failing batch) — if rate-limit errors show up in logs, drop it here.
 */
export const DEFAULT_RUN_OPTIONS: BatchOptions = { ...Presets.throughput }

export function createExecutorForChain(chainId: string): StepExecutor {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const chain = VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES]
  if (!rpcUrls || !chain) {
    throw new Error(`No RPC configuration for chain ${chainId}`)
  }
  const client = createPublicClient({ transport: createRpcTransport(rpcUrls), chain })
  // viem PublicClient satisfies Eip1193Provider via its .request method.
  // Eip1193Executor falls back to deployless Multicall3 on chains missing
  // from its deployment table (e.g. HyperEVM), so no manual multicall3
  // chain-entity injection is needed.
  return new Eip1193Executor(client)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm test -- src/lib/domino/executor.test.ts`
Expected: PASS (3 tests). If the `'8453'` case fails because `CHAIN_RPC_URLS` requires env vars at import time, wrap the test's expectations to a chain key that exists without env (check `src/config/chains.ts`) — the assertion is "supported chain returns executor", not a specific chain.

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 3: Ark task builders + assembly (`arks-overview-task.ts`)

**Files:**
- Create: `src/lib/domino/tasks/arks-overview-task.ts`
- Test: `src/lib/domino/tasks/arks-overview-task.test.ts`

**Interfaces:**
- Consumes: `MockStepExecutor`/`callKey`/`FAIL` (Task 1); `parseArkDetails`, `getArkStatus`, `ArkOverview`, `ArkDetails`, `ArksOverviewError` from `@/lib/arks-overview`.
- Produces (all consumed by Task 5):
  - `buildFleetArksIndexTask(fleet: \`0x${string}\`): MultistepTask<FleetArksIndexReads>` where `FleetArksIndexReads = { activeArks: unknown; bufferArk: unknown; asset: unknown }` (refs are untyped because the app ABIs are not const-asserted — assembly casts).
  - `buildArkOverviewTask(params: { ark: \`0x${string}\`; fleetAsset: \`0x${string}\` | null }): MultistepTask<ArkReads>`.
  - `type ArkReads` — one field per read (see code).
  - `toArkOverview(ark: \`0x${string}\`, isBufferArk: boolean, reads: ArkReads): ArkOverview` — throws `ArksOverviewError('Failed to read ark data', 502)` if any required read is `undefined`.

- [ ] **Step 1: Write the failing test**

Create `src/lib/domino/tasks/arks-overview-task.test.ts`:

```ts
import { runSettled } from '@halaprix/domino'

import { ArksOverviewError } from '@/lib/arks-overview'
import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import {
  buildArkOverviewTask,
  buildFleetArksIndexTask,
  toArkOverview,
  type ArkReads,
} from './arks-overview-task'

const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ARK = '0xA4B0000000000000000000000000000000000001' as const
const BUFFER = '0xA4B0000000000000000000000000000000000002' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const
const POOL = '0x9001000000000000000000000000000000009001' as const

function arkHandlers(overrides: Record<string, unknown> = {}) {
  return {
    [callKey(ARK, 'totalAssets')]: 1000n,
    [callKey(ARK, 'withdrawableTotalAssets')]: 900n,
    [callKey(ARK, 'name')]: 'Test Ark',
    [callKey(ARK, 'depositCap')]: 5000n,
    [callKey(ARK, 'maxDepositPercentageOfTVL')]: 100n,
    [callKey(ARK, 'maxRebalanceInflow')]: 10n,
    [callKey(ARK, 'maxRebalanceOutflow')]: 20n,
    [callKey(ARK, 'withdrawalRequestId')]: FAIL,
    [callKey(ARK, 'assetsInWithdrawalQueue')]: FAIL,
    [callKey(ARK, 'isWithdrawalClaimRequired')]: FAIL,
    [callKey(ARK, 'pendingDepositAssets')]: FAIL,
    [callKey(ARK, 'sharesToAssets')]: FAIL,
    [callKey(ARK, 'details')]: JSON.stringify({ protocol: 'ERC4626', pool: POOL, chainId: 1 }),
    [callKey(ASSET, 'balanceOf')]: 7n,
    [callKey(POOL, 'balanceOf')]: 333n,
    ...overrides,
  }
}

describe('buildFleetArksIndexTask', () => {
  it('reads activeArks, bufferArk and asset in one step', async () => {
    const executor = new MockStepExecutor({
      [callKey(FLEET, 'getActiveArks')]: [ARK],
      [callKey(FLEET, 'bufferArk')]: BUFFER,
      [callKey(FLEET, 'asset')]: ASSET,
    })
    const [result] = await runSettled(executor, [buildFleetArksIndexTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') {
      expect(result.value).toEqual({ activeArks: [ARK], bufferArk: BUFFER, asset: ASSET })
    }
    expect(executor.batches).toHaveLength(1)
  })

  it('demotes a failed asset read to undefined instead of failing the task', async () => {
    const executor = new MockStepExecutor({
      [callKey(FLEET, 'getActiveArks')]: [ARK],
      [callKey(FLEET, 'bufferArk')]: BUFFER,
      [callKey(FLEET, 'asset')]: FAIL,
    })
    const [result] = await runSettled(executor, [buildFleetArksIndexTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') expect(result.value.asset).toBeUndefined()
  })
})

describe('buildArkOverviewTask', () => {
  it('resolves base reads, details, asset balance and pool balance (pool via derived target)', async () => {
    const executor = new MockStepExecutor(arkHandlers())
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: ASSET }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    const reads = result.value as ArkReads
    expect(reads.totalAssets).toBe(1000n)
    expect(reads.details).toEqual({ protocol: 'ERC4626', pool: POOL, chainId: 1 })
    expect(reads.assetBalance).toBe(7n)
    expect(reads.poolBalance).toBe(333n)
    // base+details in step 1, pool balanceOf in step 2 => exactly 2 round-trips
    expect(executor.batches).toHaveLength(2)
  })

  it('skips the pool balance call when details() fails or has no resolvable pool', async () => {
    const executor = new MockStepExecutor(arkHandlers({ [callKey(ARK, 'details')]: FAIL }))
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: ASSET }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    const reads = result.value as ArkReads
    expect(reads.details).toBeNull()
    expect(reads.poolBalance).toBeUndefined()
  })

  it('omits the asset balanceOf call when the fleet has no readable asset', async () => {
    const executor = new MockStepExecutor(arkHandlers())
    const [result] = await runSettled(executor, [
      buildArkOverviewTask({ ark: ARK, fleetAsset: null }),
    ])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect((result.value as ArkReads).assetBalance).toBeUndefined()
  })
})

describe('toArkOverview', () => {
  const baseReads: ArkReads = {
    totalAssets: 1000n,
    withdrawableTotalAssets: 900n,
    name: 'Test Ark',
    depositCap: 5000n,
    maxDepositPercentageOfTVL: 100n,
    maxRebalanceInflow: 10n,
    maxRebalanceOutflow: 20n,
    withdrawalRequestId: undefined,
    assetsInWithdrawalQueue: undefined,
    isWithdrawalClaimRequired: undefined,
    pendingDepositAssets: undefined,
    sharesToAssets1e18: undefined,
    assetBalance: 7n,
    details: { protocol: 'ERC4626', pool: POOL, chainId: 1 },
    poolBalance: 333n,
  }

  it('produces the legacy ArkOverview shape (bigints stringified, needsSweep derived)', () => {
    expect(toArkOverview(ARK, false, baseReads)).toEqual({
      address: ARK,
      totalAssets: '1000',
      withdrawableTotalAssets: '900',
      name: 'Test Ark',
      depositCap: '5000',
      maxDepositPercentageOfTVL: '100',
      maxRebalanceInflow: '10',
      maxRebalanceOutflow: '20',
      isBufferArk: false,
      status: 'active',
      details: { protocol: 'ERC4626', pool: POOL, chainId: 1 },
      poolBalance: '333',
      assetBalance: '7',
      needsSweep: true,
    })
  })

  it('includes withdrawal-queue keys only when at least one queue read succeeded', () => {
    const withQueue = toArkOverview(ARK, false, {
      ...baseReads,
      withdrawalRequestId: 3n,
      assetsInWithdrawalQueue: 50n,
      isWithdrawalClaimRequired: false,
    })
    expect(withQueue.withdrawalRequestId).toBe('3')
    expect(withQueue.assetsInWithdrawalQueue).toBe('50')
    expect(withQueue.isWithdrawalClaimRequired).toBe(false)
    expect('withdrawalRequestId' in toArkOverview(ARK, false, baseReads)).toBe(false)
  })

  it('includes wisdomtree keys only when present, and marks statuses', () => {
    const wt = toArkOverview(ARK, false, {
      ...baseReads,
      pendingDepositAssets: 5n,
      sharesToAssets1e18: 2000000000000000000n,
      depositCap: 0n,
      totalAssets: 0n,
      assetBalance: 0n,
    })
    expect(wt.pendingDepositAssets).toBe('5')
    expect(wt.sharesToAssets1e18).toBe('2000000000000000000')
    expect(wt.status).toBe('ready-to-remove')
    expect(wt.needsSweep).toBe(false)
    expect(toArkOverview(ARK, true, baseReads).status).toBe('active')
    expect(toArkOverview(ARK, true, baseReads).isBufferArk).toBe(true)
  })

  it('throws ArksOverviewError(502) when a required base read is missing', () => {
    expect(() =>
      toArkOverview(ARK, false, { ...baseReads, totalAssets: undefined as unknown as bigint }),
    ).toThrow(ArksOverviewError)
    try {
      toArkOverview(ARK, false, { ...baseReads, name: undefined as unknown as string })
    } catch (err) {
      expect((err as ArksOverviewError).message).toBe('Failed to read ark data')
      expect((err as ArksOverviewError).status).toBe(502)
    }
  })

  it('keeps poolBalance null when the pool read did not resolve', () => {
    const result = toArkOverview(ARK, false, { ...baseReads, poolBalance: undefined })
    expect(result.poolBalance).toBeNull()
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test -- src/lib/domino/tasks/arks-overview-task.test.ts`
Expected: FAIL — `Cannot find module './arks-overview-task'`.

- [ ] **Step 3: Write the implementation**

Create `src/lib/domino/tasks/arks-overview-task.ts`:

```ts
import { defineTask, type MultistepTask } from '@halaprix/domino'

import { arkAbi } from '@/abis/Ark'
import { arkWithWithdrawalRequestAbi } from '@/abis/ArkWithWithdrawalRequest'
import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { wisdomTreeArkAbi } from '@/abis/WisdomTreeArk'
import {
  ArksOverviewError,
  getArkStatus,
  parseArkDetails,
  type ArkDetails,
  type ArkOverview,
} from '@/lib/arks-overview'

type Address = `0x${string}`

export interface FleetArksIndexReads {
  activeArks: unknown
  bufferArk: unknown
  asset: unknown
}

/** Step 1 of the two-phase ark overview: discover the fleet's arks. */
export function buildFleetArksIndexTask(fleet: Address): MultistepTask<FleetArksIndexReads> {
  return defineTask((t) => ({
    activeArks: t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'getActiveArks',
      optional: true,
    }),
    bufferArk: t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'bufferArk',
      optional: true,
    }),
    asset: t.call({ target: fleet, abi: fleetCommanderAbi, functionName: 'asset', optional: true }),
  }))
}

export interface ArkReads {
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  name: string | undefined
  depositCap: bigint | undefined
  maxDepositPercentageOfTVL: bigint | undefined
  maxRebalanceInflow: bigint | undefined
  maxRebalanceOutflow: bigint | undefined
  withdrawalRequestId: bigint | undefined
  assetsInWithdrawalQueue: bigint | undefined
  isWithdrawalClaimRequired: boolean | undefined
  pendingDepositAssets: bigint | undefined
  sharesToAssets1e18: bigint | undefined
  assetBalance: bigint | undefined
  details: ArkDetails | null
  poolBalance: bigint | undefined
}

/**
 * Full per-ark read graph. Base reads + details() land in step 1; the pool
 * token balanceOf runs in step 2 against a target derived from details()
 * (skip-chained to undefined when the pool is not a resolvable address —
 * Aave-fork/Sky/Morpho-Blue arks, or a failed details() call).
 */
export function buildArkOverviewTask(params: {
  ark: Address
  fleetAsset: Address | null
}): MultistepTask<ArkReads> {
  const { ark, fleetAsset } = params
  return defineTask((t) => {
    const detailsJson = t.call({
      target: ark,
      abi: arkAbi,
      functionName: 'details',
      optional: true,
    })
    const details = t.derive([detailsJson], (json) =>
      parseArkDetails(json as string | undefined),
    )
    const poolAddress = t.derive([details], (d) => (d as ArkDetails | null)?.pool)

    return {
      totalAssets: t.call({ target: ark, abi: arkAbi, functionName: 'totalAssets', optional: true }),
      withdrawableTotalAssets: t.call({
        target: ark,
        abi: arkAbi,
        functionName: 'withdrawableTotalAssets',
        optional: true,
      }),
      name: t.call({ target: ark, abi: arkAbi, functionName: 'name', optional: true }),
      depositCap: t.call({ target: ark, abi: arkAbi, functionName: 'depositCap', optional: true }),
      maxDepositPercentageOfTVL: t.call({
        target: ark,
        abi: arkAbi,
        functionName: 'maxDepositPercentageOfTVL',
        optional: true,
      }),
      maxRebalanceInflow: t.call({
        target: ark,
        abi: arkAbi,
        functionName: 'maxRebalanceInflow',
        optional: true,
      }),
      maxRebalanceOutflow: t.call({
        target: ark,
        abi: arkAbi,
        functionName: 'maxRebalanceOutflow',
        optional: true,
      }),
      withdrawalRequestId: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'withdrawalRequestId',
        optional: true,
      }),
      assetsInWithdrawalQueue: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'assetsInWithdrawalQueue',
        optional: true,
      }),
      isWithdrawalClaimRequired: t.call({
        target: ark,
        abi: arkWithWithdrawalRequestAbi,
        functionName: 'isWithdrawalClaimRequired',
        optional: true,
      }),
      pendingDepositAssets: t.call({
        target: ark,
        abi: wisdomTreeArkAbi,
        functionName: 'pendingDepositAssets',
        optional: true,
      }),
      sharesToAssets1e18: t.call({
        target: ark,
        abi: wisdomTreeArkAbi,
        functionName: 'sharesToAssets',
        args: [1000000000000000000n],
        optional: true,
      }),
      assetBalance: fleetAsset
        ? t.call({
            target: fleetAsset,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [ark],
            optional: true,
          })
        : undefined,
      details,
      poolBalance: t.call({
        target: poolAddress as never, // Ref<Address | undefined> — skip-chain handles undefined
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [ark],
        optional: true,
      }),
    } as unknown as ArkReads // ABIs are not const-asserted; refs degrade to unknown
  }) as MultistepTask<ArkReads>
}

function requireRead<T>(value: T | undefined): T {
  if (value === undefined) throw new ArksOverviewError('Failed to read ark data', 502)
  return value
}

/** Pure assembly: resolved reads -> legacy ArkOverview JSON shape. */
export function toArkOverview(ark: Address, isBufferArk: boolean, reads: ArkReads): ArkOverview {
  const totalAssets = requireRead(reads.totalAssets)
  const depositCap = requireRead(reads.depositCap)
  const name = requireRead(reads.name)
  const withdrawableTotalAssets = requireRead(reads.withdrawableTotalAssets)
  const maxDepositPercentageOfTVL = requireRead(reads.maxDepositPercentageOfTVL)
  const maxRebalanceInflow = requireRead(reads.maxRebalanceInflow)
  const maxRebalanceOutflow = requireRead(reads.maxRebalanceOutflow)

  const hasWithdrawalQueue =
    reads.withdrawalRequestId !== undefined ||
    reads.assetsInWithdrawalQueue !== undefined ||
    reads.isWithdrawalClaimRequired !== undefined
  const assetBalance = reads.assetBalance?.toString()

  return {
    address: ark,
    totalAssets: totalAssets.toString(),
    withdrawableTotalAssets: withdrawableTotalAssets.toString(),
    name: String(name),
    depositCap: depositCap.toString(),
    maxDepositPercentageOfTVL: maxDepositPercentageOfTVL.toString(),
    maxRebalanceInflow: maxRebalanceInflow.toString(),
    maxRebalanceOutflow: maxRebalanceOutflow.toString(),
    isBufferArk,
    status: getArkStatus({ isBufferArk, depositCap, totalAssets }),
    details: reads.details,
    poolBalance: reads.poolBalance?.toString() ?? null,
    ...(hasWithdrawalQueue && {
      withdrawalRequestId: reads.withdrawalRequestId?.toString(),
      assetsInWithdrawalQueue: reads.assetsInWithdrawalQueue?.toString(),
      isWithdrawalClaimRequired: reads.isWithdrawalClaimRequired,
    }),
    assetBalance,
    needsSweep: assetBalance !== undefined && assetBalance !== '0',
    ...(reads.pendingDepositAssets !== undefined && {
      pendingDepositAssets: reads.pendingDepositAssets.toString(),
    }),
    ...(reads.sharesToAssets1e18 !== undefined && {
      sharesToAssets1e18: reads.sharesToAssets1e18.toString(),
    }),
  }
}
```

Implementation note: if `target: poolAddress as never` fights the compiler differently than expected, the correct runtime value is the `Ref` itself — adjust the cast (`as unknown as Address`), never the graph shape. If the mock-driven test shows the pool call was dispatched with an `undefined` target instead of being skipped, that is a plan-stopping finding: fall back to resolving pool balances with a second `runSettled` phase (mirroring the current Multicall 4) and record it in this file's header comment.

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm test -- src/lib/domino/tasks/arks-overview-task.test.ts`
Expected: PASS (all describes). Pay attention to the `executor.batches` length assertions — they prove the round-trip claim (2 instead of the legacy 3 per-ark stages).

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 4: Fleet summary task builders (same module)

**Files:**
- Modify: `src/lib/domino/tasks/arks-overview-task.ts` (append)
- Test: `src/lib/domino/tasks/arks-overview-task.test.ts` (append)

**Interfaces:**
- Produces (consumed by Task 5):
  - `buildActiveFleetsTask(harbor: Address): MultistepTask<{ fleets: unknown }>` (also reused by the tipjar core in Task 6).
  - `buildFleetSummaryTask(fleet: Address): MultistepTask<FleetSummaryReads>` — fleet reads in step 1, asset `decimals`/`symbol` in step 2 via the asset ref as target.
  - `toFleetSummary(fleet: Address, reads: FleetSummaryReads): FleetSummary` — throws `ArksOverviewError('Failed to read fleet contract', 502)` when a fleet-level read is missing, `ArksOverviewError('Failed to read asset contract', 502)` when only the asset-level reads are missing.

- [ ] **Step 1: Write the failing tests (append to the test file)**

```ts
import {
  buildActiveFleetsTask,
  buildFleetSummaryTask,
  toFleetSummary,
  type FleetSummaryReads,
} from './arks-overview-task'

const HARBOR = '0x4A4B04000000000000000000000000000000004A' as const

describe('buildActiveFleetsTask', () => {
  it('reads getActiveFleetCommanders', async () => {
    const executor = new MockStepExecutor({
      [callKey(HARBOR, 'getActiveFleetCommanders')]: [FLEET],
    })
    const [result] = await runSettled(executor, [buildActiveFleetsTask(HARBOR)])
    expect(result.status).toBe('fulfilled')
    if (result.status === 'fulfilled') expect(result.value.fleets).toEqual([FLEET])
  })
})

describe('buildFleetSummaryTask + toFleetSummary', () => {
  const config = {
    bufferArk: BUFFER,
    minimumBufferBalance: 100n,
    depositCap: 9000n,
    maxRebalanceOperations: 4n,
    stakingRewardsManager: '0x0000000000000000000000000000000000000001',
  }
  const handlers = {
    [callKey(FLEET, 'name')]: 'Fleet One',
    [callKey(FLEET, 'symbol')]: 'FL1',
    [callKey(FLEET, 'asset')]: ASSET,
    [callKey(FLEET, 'totalAssets')]: 12345n,
    [callKey(FLEET, 'withdrawableTotalAssets')]: 12000n,
    [callKey(FLEET, 'getConfig')]: config,
    [callKey(ASSET, 'decimals')]: 6,
    [callKey(ASSET, 'symbol')]: 'USDC',
  }

  it('resolves fleet + nested asset reads in two round-trips and assembles FleetSummary', async () => {
    const executor = new MockStepExecutor(handlers)
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect(executor.batches).toHaveLength(2)
    expect(toFleetSummary(FLEET, result.value as FleetSummaryReads)).toEqual({
      address: FLEET,
      name: 'Fleet One',
      symbol: 'FL1',
      asset: ASSET,
      totalAssets: '12345',
      withdrawableTotalAssets: '12000',
      depositCap: '9000',
      minimumBufferBalance: '100',
      maxRebalanceOperations: '4',
      assetDecimals: 6,
      assetSymbol: 'USDC',
      fleetDecimals: 6,
    })
  })

  it('maps a fleet-level failure to the legacy fleet error', async () => {
    const executor = new MockStepExecutor({ ...handlers, [callKey(FLEET, 'name')]: FAIL })
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(() => toFleetSummary(FLEET, result.value as FleetSummaryReads)).toThrow(
      'Failed to read fleet contract',
    )
  })

  it('maps an asset-level failure to the legacy asset error', async () => {
    const executor = new MockStepExecutor({ ...handlers, [callKey(ASSET, 'decimals')]: FAIL })
    const [result] = await runSettled(executor, [buildFleetSummaryTask(FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(() => toFleetSummary(FLEET, result.value as FleetSummaryReads)).toThrow(
      'Failed to read asset contract',
    )
  })
})
```

(Reuse the `FLEET`/`BUFFER`/`ASSET` consts already defined at the top of the test file.)

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `pnpm test -- src/lib/domino/tasks/arks-overview-task.test.ts`
Expected: FAIL — `buildActiveFleetsTask` etc. are not exported.

- [ ] **Step 3: Write the implementation (append to `arks-overview-task.ts`)**

```ts
import type { FleetSummary } from '@/lib/arks-overview' // merge into the existing import

import { harborCommandAbi } from '@/abis/HarborCommand' // top of file

export function buildActiveFleetsTask(harbor: Address): MultistepTask<{ fleets: unknown }> {
  return defineTask((t) => ({
    fleets: t.call({
      target: harbor,
      abi: harborCommandAbi,
      functionName: 'getActiveFleetCommanders',
      optional: true,
    }),
  }))
}

export interface FleetSummaryReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  config: unknown
  assetDecimals: number | undefined
  assetSymbol: string | undefined
}

export function buildFleetSummaryTask(fleet: Address): MultistepTask<FleetSummaryReads> {
  return defineTask((t) => {
    const asset = t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'asset',
      optional: true,
    })
    return {
      name: t.call({ target: fleet, abi: fleetCommanderAbi, functionName: 'name', optional: true }),
      symbol: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'symbol',
        optional: true,
      }),
      asset,
      totalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'totalAssets',
        optional: true,
      }),
      withdrawableTotalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'withdrawableTotalAssets',
        optional: true,
      }),
      config: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'getConfig',
        optional: true,
      }),
      assetDecimals: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'decimals',
        optional: true,
      }),
      assetSymbol: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'symbol',
        optional: true,
      }),
    } as unknown as FleetSummaryReads
  }) as MultistepTask<FleetSummaryReads>
}

export function toFleetSummary(fleet: Address, reads: FleetSummaryReads): FleetSummary {
  if (
    reads.name === undefined ||
    reads.symbol === undefined ||
    reads.asset === undefined ||
    reads.totalAssets === undefined ||
    reads.withdrawableTotalAssets === undefined ||
    reads.config === undefined
  ) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  if (reads.assetDecimals === undefined || reads.assetSymbol === undefined) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }
  const config = reads.config as {
    bufferArk: Address
    minimumBufferBalance: bigint
    depositCap: bigint
    maxRebalanceOperations: bigint
    stakingRewardsManager: Address
  }
  const assetDecimals = Number(reads.assetDecimals)
  return {
    address: fleet,
    name: String(reads.name),
    symbol: String(reads.symbol),
    asset: reads.asset,
    totalAssets: reads.totalAssets.toString(),
    withdrawableTotalAssets: reads.withdrawableTotalAssets.toString(),
    depositCap: config.depositCap.toString(),
    minimumBufferBalance: config.minimumBufferBalance.toString(),
    maxRebalanceOperations: config.maxRebalanceOperations.toString(),
    assetDecimals,
    assetSymbol: String(reads.assetSymbol),
    fleetDecimals: assetDecimals,
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pnpm test -- src/lib/domino/tasks/arks-overview-task.test.ts`
Expected: PASS.

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 5: Refactor `src/lib/arks-overview.ts` onto the task layer

**Files:**
- Modify: `src/lib/arks-overview.ts` (bodies of `getFleetsForChain` and `getArksForFleet`; everything else — types, `getArkStatus`, `parseArkDetails`, `computeBufferSharePct`, `getAllArksOverview` — unchanged)
- Test: `src/lib/arks-overview.test.ts` (append executor-injected coverage)

**Interfaces:**
- Consumes: everything from Tasks 1–4.
- Produces: `getFleetsForChain(chainId, environment, executor?)` and `getArksForFleet(chainId, fleetAddress, executor?)` — same names/return types, new optional trailing `executor?: StepExecutor` (defaults to `createExecutorForChain(chainId)`). `getAllArksOverview` unchanged.

- [ ] **Step 1: Write the failing tests (append to `src/lib/arks-overview.test.ts`)**

```ts
import { callKey, FAIL, MockStepExecutor } from './domino/testing/mock-executor'
import { ArksOverviewError, getArksForFleet, getFleetsForChain } from './arks-overview'

const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ARK = '0xA4B0000000000000000000000000000000000001' as const
const BUFFER = '0xA4B0000000000000000000000000000000000002' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const

const arkReads = (ark: string) => ({
  [callKey(ark, 'totalAssets')]: 100n,
  [callKey(ark, 'withdrawableTotalAssets')]: 90n,
  [callKey(ark, 'name')]: `ark-${ark.slice(-1)}`,
  [callKey(ark, 'depositCap')]: 1000n,
  [callKey(ark, 'maxDepositPercentageOfTVL')]: 50n,
  [callKey(ark, 'maxRebalanceInflow')]: 1n,
  [callKey(ark, 'maxRebalanceOutflow')]: 2n,
  [callKey(ark, 'withdrawalRequestId')]: FAIL,
  [callKey(ark, 'assetsInWithdrawalQueue')]: FAIL,
  [callKey(ark, 'isWithdrawalClaimRequired')]: FAIL,
  [callKey(ark, 'pendingDepositAssets')]: FAIL,
  [callKey(ark, 'sharesToAssets')]: FAIL,
  [callKey(ark, 'details')]: FAIL,
})

describe('getArksForFleet (domino path, injected executor)', () => {
  const handlers = {
    [callKey(FLEET, 'getActiveArks')]: [ARK],
    [callKey(FLEET, 'bufferArk')]: BUFFER,
    [callKey(FLEET, 'asset')]: ASSET,
    [callKey(ASSET, 'balanceOf')]: 0n,
    ...arkReads(ARK),
    ...arkReads(BUFFER),
  }

  it('returns active arks + buffer ark last, with legacy shape', async () => {
    const arks = await getArksForFleet('8453', FLEET, new MockStepExecutor(handlers))
    expect(arks).toHaveLength(2)
    expect(arks[0].address).toBe(ARK)
    expect(arks[1].address).toBe(BUFFER)
    expect(arks[1].isBufferArk).toBe(true)
    expect(arks[0]).toMatchObject({
      totalAssets: '100',
      status: 'active',
      details: null,
      poolBalance: null,
      needsSweep: false,
      assetBalance: '0',
    })
    expect(arks[0]).not.toHaveProperty('withdrawalRequestId')
  })

  it('throws 502 when fleet index reads fail', async () => {
    const executor = new MockStepExecutor({
      ...handlers,
      [callKey(FLEET, 'getActiveArks')]: FAIL,
    })
    await expect(getArksForFleet('8453', FLEET, executor)).rejects.toThrow(
      'Failed to read fleet arks',
    )
  })

  it('throws 502 when any ark base read fails', async () => {
    const executor = new MockStepExecutor({
      ...handlers,
      [callKey(ARK, 'totalAssets')]: FAIL,
    })
    await expect(getArksForFleet('8453', FLEET, executor)).rejects.toThrow(
      'Failed to read ark data',
    )
  })

  it('throws 400 for an unsupported chainId without touching the executor', async () => {
    await expect(getArksForFleet('42', FLEET)).rejects.toMatchObject({
      message: 'Unsupported chainId',
      status: 400,
    })
  })
})

describe('getFleetsForChain (domino path, injected executor)', () => {
  it('appends the hard-coded Base fleet on chain 8453', async () => {
    const EXTRA = '0x29f13a877F3d1A14AC0B15B07536D4423b35E198'
    const fleetHandlers = (fleet: string) => ({
      [callKey(fleet, 'name')]: 'F',
      [callKey(fleet, 'symbol')]: 'F',
      [callKey(fleet, 'asset')]: ASSET,
      [callKey(fleet, 'totalAssets')]: 1n,
      [callKey(fleet, 'withdrawableTotalAssets')]: 1n,
      [callKey(fleet, 'getConfig')]: {
        bufferArk: BUFFER,
        minimumBufferBalance: 0n,
        depositCap: 0n,
        maxRebalanceOperations: 0n,
        stakingRewardsManager: ASSET,
      },
    })
    const executor = new MockStepExecutor({
      // production Base harbor address — copy the actual value from
      // HARBOR_COMMAND_ADDRESSES.production[8453] in src/config/environments.ts
      [callKey(HARBOR_8453, 'getActiveFleetCommanders')]: [FLEET],
      [callKey(ASSET, 'decimals')]: 6,
      [callKey(ASSET, 'symbol')]: 'USDC',
      ...fleetHandlers(FLEET),
      ...fleetHandlers(EXTRA),
    })
    const fleets = await getFleetsForChain('8453', 'production', executor)
    expect(fleets.map((f) => f.address)).toEqual([FLEET, EXTRA])
    expect(fleets[0].assetDecimals).toBe(6)
  })
})
```

(Define `HARBOR_8453` as a const at the top of the describe with the real address from `src/config/environments.ts` — read it while writing the test.)

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `pnpm test -- src/lib/arks-overview.test.ts`
Expected: New describes FAIL (`getArksForFleet` doesn't accept a third argument / hits real RPC config); the four existing pure-function describes still PASS.

- [ ] **Step 3: Rewrite the two functions**

In `src/lib/arks-overview.ts`:
- Remove imports of `createPublicClient` and all ABI imports that become unused; add:

```ts
import { runSettled, type StepExecutor } from '@halaprix/domino'

import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'
import {
  buildActiveFleetsTask,
  buildArkOverviewTask,
  buildFleetArksIndexTask,
  buildFleetSummaryTask,
  toArkOverview,
  toFleetSummary,
  type FleetSummaryReads,
} from '@/lib/domino/tasks/arks-overview-task'
```

- Replace `getFleetsForChain` body:

```ts
export async function getFleetsForChain(
  chainId: string,
  environment: Environment,
  executor?: StepExecutor,
): Promise<FleetSummary[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  const harbor = HARBOR_COMMAND_ADDRESSES[environment][Number(chainId)]
  if (!rpcUrls || !harbor) {
    throw new ArksOverviewError('Unsupported chain or environment', 400)
  }
  const exec = executor ?? createExecutorForChain(chainId)

  const [harborResult] = await runSettled(
    exec,
    [buildActiveFleetsTask(harbor as `0x${string}`)],
    DEFAULT_RUN_OPTIONS,
  )
  const activeFleets =
    harborResult.status === 'fulfilled' && harborResult.value.fleets !== undefined
      ? (harborResult.value.fleets as `0x${string}`[])
      : undefined
  if (activeFleets === undefined) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }

  const allFleets = [...activeFleets]
  if (chainId === '8453') {
    allFleets.push('0x29f13a877F3d1A14AC0B15B07536D4423b35E198' as `0x${string}`)
  }

  const settled = await runSettled(
    exec,
    allFleets.map((fleet) => buildFleetSummaryTask(fleet)),
    DEFAULT_RUN_OPTIONS,
  )
  return settled.map((result, i) => {
    if (result.status === 'rejected') {
      throw new ArksOverviewError('Failed to read fleet contract', 502)
    }
    return toFleetSummary(allFleets[i], result.value as FleetSummaryReads)
  })
}
```

Behavioral note (accepted, document in the PR): the legacy code threw a raw viem error if `getActiveFleetCommanders` itself reverted; it now throws `ArksOverviewError(502)` — `getAllArksOverview` catches both identically (`error: (err as Error).message`).

- Replace `getArksForFleet` body:

```ts
export async function getArksForFleet(
  chainId: string,
  fleetAddress: `0x${string}`,
  executor?: StepExecutor,
): Promise<ArkOverview[]> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) throw new ArksOverviewError('Unsupported chainId', 400)
  const exec = executor ?? createExecutorForChain(chainId)

  const [indexResult] = await runSettled(
    exec,
    [buildFleetArksIndexTask(fleetAddress)],
    DEFAULT_RUN_OPTIONS,
  )
  if (indexResult.status === 'rejected') {
    throw new ArksOverviewError('Failed to read fleet arks', 502)
  }
  const activeArks = indexResult.value.activeArks as `0x${string}`[] | undefined
  const bufferArkAddress = indexResult.value.bufferArk as `0x${string}` | undefined
  const assetAddress = (indexResult.value.asset as `0x${string}` | undefined) ?? null
  if (activeArks === undefined || bufferArkAddress === undefined) {
    throw new ArksOverviewError('Failed to read fleet arks', 502)
  }

  const allArks = [...activeArks, bufferArkAddress]
  if (allArks.length === 0) return []

  const settled = await runSettled(
    exec,
    allArks.map((ark) => buildArkOverviewTask({ ark, fleetAsset: assetAddress })),
    DEFAULT_RUN_OPTIONS,
  )
  return settled.map((result, i) => {
    if (result.status === 'rejected') {
      throw new ArksOverviewError('Failed to read ark data', 502)
    }
    return toArkOverview(allArks[i], i === allArks.length - 1, result.value)
  })
}
```

`getAllArksOverview` is untouched.

- [ ] **Step 4: Run the full package test suite**

Run: `pnpm test`
Expected: PASS — all existing tests plus the new describes. Then `pnpm lint` for unused-import fallout.

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 6: TipJar task builders + `getTipjarPayload` core (`tipjar-task.ts`)

**Files:**
- Create: `src/lib/domino/tasks/tipjar-task.ts`
- Test: `src/lib/domino/tasks/tipjar-task.test.ts`

**Interfaces:**
- Consumes: Tasks 1–2; `buildActiveFleetsTask` (Task 4); `getHarborCommand`, `getTipJarInstances` from `@/app/tipjar/lib/tipJarConfig`; `ArksOverviewError` from `@/lib/arks-overview`.
- Produces (consumed by Task 7):
  - `buildTipJarInstanceTask(instance: Address): MultistepTask<TipJarInstanceReads>` (streams/totalAllocation/paused, all optional).
  - `buildTipJarFleetMetaTask(fleet: Address): MultistepTask<TipJarFleetMetaReads>` (name/symbol/asset + asset decimals/symbol via ref target, all optional).
  - `buildTipJarPendingTask(instance: Address, fleet: Address): MultistepTask<TipJarPendingReads>` — `balanceOf(instance)` then `convertToAssets(sharesRef)` via ref **args**.
  - `getTipjarPayload(chainId: ChainId, executor?: StepExecutor): Promise<TipjarPayload>` — throws `ArksOverviewError('Unsupported chain or no TipJar deployed', 400)` when unsupported; otherwise returns the exact legacy payload `{ chainId, instances: [...] }` with all legacy defaults.

- [ ] **Step 1: Write the failing test**

Create `src/lib/domino/tasks/tipjar-task.test.ts`:

```ts
import { runSettled } from '@halaprix/domino'

import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import {
  buildTipJarFleetMetaTask,
  buildTipJarInstanceTask,
  buildTipJarPendingTask,
  getTipjarPayload,
} from './tipjar-task'

jest.mock('@/app/tipjar/lib/tipJarConfig', () => ({
  getTipJarInstances: (chainId: string) =>
    chainId === '8453'
      ? [{ label: 'TipJar v1', address: '0x7191000000000000000000000000000000000071' }]
      : [],
  getHarborCommand: (chainId: string) =>
    chainId === '8453' ? '0x4A4B04000000000000000000000000000000004A' : null,
}))

const TIPJAR = '0x7191000000000000000000000000000000000071' as const
const HARBOR = '0x4A4B04000000000000000000000000000000004A' as const
const FLEET = '0xF1EE7000000000000000000000000000000000F1' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const

const STREAM = {
  recipient: '0x0000000000000000000000000000000000000009' as const,
  allocation: 250n,
  lockedUntilEpoch: 12n,
}

const happyHandlers = {
  [callKey(HARBOR, 'getActiveFleetCommanders')]: [FLEET],
  [callKey(TIPJAR, 'getAllTipStreams')]: [STREAM],
  [callKey(TIPJAR, 'getTotalAllocation')]: 250n,
  [callKey(TIPJAR, 'paused')]: false,
  [callKey(FLEET, 'name')]: 'Fleet One',
  [callKey(FLEET, 'symbol')]: 'FL1',
  [callKey(FLEET, 'asset')]: ASSET,
  [callKey(ASSET, 'decimals')]: 6,
  [callKey(ASSET, 'symbol')]: 'USDC',
  [callKey(FLEET, 'balanceOf')]: 500n,
  [callKey(FLEET, 'convertToAssets')]: (args: readonly unknown[] | undefined) =>
    args?.[0] === 500n ? 510n : 0n,
}

describe('buildTipJarPendingTask', () => {
  it('feeds the balanceOf result into convertToAssets via a ref arg', async () => {
    const executor = new MockStepExecutor(happyHandlers)
    const [result] = await runSettled(executor, [buildTipJarPendingTask(TIPJAR, FLEET)])
    expect(result.status).toBe('fulfilled')
    if (result.status !== 'fulfilled') return
    expect(result.value).toEqual({ pendingShares: 500n, pendingAssets: 510n })
    expect(executor.batches).toHaveLength(2)
  })

  it('skips convertToAssets when balanceOf fails', async () => {
    const executor = new MockStepExecutor({ ...happyHandlers, [callKey(FLEET, 'balanceOf')]: FAIL })
    const [result] = await runSettled(executor, [buildTipJarPendingTask(TIPJAR, FLEET)])
    if (result.status !== 'fulfilled') throw new Error('expected fulfilled')
    expect(result.value).toEqual({ pendingShares: undefined, pendingAssets: undefined })
  })
})

describe('getTipjarPayload', () => {
  it('throws 400 for a chain with no TipJar', async () => {
    await expect(getTipjarPayload('1' as never, new MockStepExecutor({}))).rejects.toMatchObject({
      message: 'Unsupported chain or no TipJar deployed',
      status: 400,
    })
  })

  it('assembles the exact legacy payload on the happy path', async () => {
    const payload = await getTipjarPayload('8453' as never, new MockStepExecutor(happyHandlers))
    expect(payload).toEqual({
      chainId: '8453',
      instances: [
        {
          label: 'TipJar v1',
          address: TIPJAR,
          paused: false,
          totalAllocation: '250',
          streams: [
            { recipient: STREAM.recipient, allocation: '250', lockedUntilEpoch: '12' },
          ],
          fleets: [
            {
              address: FLEET,
              name: 'Fleet One',
              assetSymbol: 'USDC',
              assetDecimals: 6,
              pendingShares: '500',
              pendingAssets: '510',
            },
          ],
        },
      ],
    })
  })

  it('applies legacy defaults on partial failures (unknown fleet, 18 decimals, zero pendings, empty streams)', async () => {
    const executor = new MockStepExecutor({
      ...happyHandlers,
      [callKey(TIPJAR, 'getAllTipStreams')]: FAIL,
      [callKey(TIPJAR, 'getTotalAllocation')]: FAIL,
      [callKey(TIPJAR, 'paused')]: FAIL,
      [callKey(FLEET, 'name')]: FAIL,
      [callKey(FLEET, 'symbol')]: FAIL,
      [callKey(FLEET, 'asset')]: FAIL,
      [callKey(FLEET, 'balanceOf')]: FAIL,
    })
    const payload = await getTipjarPayload('8453' as never, executor)
    const instance = payload.instances[0]
    expect(instance.paused).toBe(false)
    expect(instance.totalAllocation).toBe('0')
    expect(instance.streams).toEqual([])
    expect(instance.fleets[0]).toEqual({
      address: FLEET,
      name: 'Unknown fleet',
      assetSymbol: '',
      assetDecimals: 18,
      pendingShares: '0',
      pendingAssets: '0',
    })
  })

  it('returns instances with empty fleets when the harbor read fails', async () => {
    const executor = new MockStepExecutor({
      ...happyHandlers,
      [callKey(HARBOR, 'getActiveFleetCommanders')]: FAIL,
    })
    const payload = await getTipjarPayload('8453' as never, executor)
    expect(payload.instances[0].fleets).toEqual([])
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test -- src/lib/domino/tasks/tipjar-task.test.ts`
Expected: FAIL — `Cannot find module './tipjar-task'`.

- [ ] **Step 3: Write the implementation**

Create `src/lib/domino/tasks/tipjar-task.ts`:

```ts
import { defineTask, runSettled, type MultistepTask, type StepExecutor } from '@halaprix/domino'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { tipJarAbi } from '@/abis/TipJar'
import { getHarborCommand, getTipJarInstances } from '@/app/tipjar/lib/tipJarConfig'
import { ArksOverviewError } from '@/lib/arks-overview'
import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'
import { buildActiveFleetsTask } from '@/lib/domino/tasks/arks-overview-task'
import type { ChainId } from '@/types'

type Address = `0x${string}`

type RawStream = { recipient: Address; allocation: bigint; lockedUntilEpoch: bigint }

export interface TipJarInstanceReads {
  streams: readonly RawStream[] | undefined
  totalAllocation: bigint | undefined
  paused: boolean | undefined
}

export function buildTipJarInstanceTask(instance: Address): MultistepTask<TipJarInstanceReads> {
  return defineTask((t) => ({
    streams: t.call({
      target: instance,
      abi: tipJarAbi,
      functionName: 'getAllTipStreams',
      optional: true,
    }),
    totalAllocation: t.call({
      target: instance,
      abi: tipJarAbi,
      functionName: 'getTotalAllocation',
      optional: true,
    }),
    paused: t.call({ target: instance, abi: tipJarAbi, functionName: 'paused', optional: true }),
  })) as MultistepTask<TipJarInstanceReads>
}

export interface TipJarFleetMetaReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  assetDecimals: number | undefined
  assetSymbol: string | undefined
}

export function buildTipJarFleetMetaTask(fleet: Address): MultistepTask<TipJarFleetMetaReads> {
  return defineTask((t) => {
    const asset = t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'asset',
      optional: true,
    })
    return {
      name: t.call({ target: fleet, abi: fleetCommanderAbi, functionName: 'name', optional: true }),
      symbol: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'symbol',
        optional: true,
      }),
      asset,
      assetDecimals: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'decimals',
        optional: true,
      }),
      assetSymbol: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'symbol',
        optional: true,
      }),
    } as unknown as TipJarFleetMetaReads
  }) as MultistepTask<TipJarFleetMetaReads>
}

export interface TipJarPendingReads {
  pendingShares: bigint | undefined
  pendingAssets: bigint | undefined
}

export function buildTipJarPendingTask(
  instance: Address,
  fleet: Address,
): MultistepTask<TipJarPendingReads> {
  return defineTask((t) => {
    const shares = t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'balanceOf',
      args: [instance],
      optional: true,
    })
    return {
      pendingShares: shares,
      pendingAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'convertToAssets',
        args: [shares as never],
        optional: true,
      }),
    } as unknown as TipJarPendingReads
  }) as MultistepTask<TipJarPendingReads>
}

export interface TipjarPayload {
  chainId: ChainId
  instances: Array<{
    label: string
    address: Address
    paused: boolean
    totalAllocation: string
    streams: Array<{ recipient: Address; allocation: string; lockedUntilEpoch: string }>
    fleets: Array<{
      address: Address
      name: string
      assetSymbol: string
      assetDecimals: number
      pendingShares: string
      pendingAssets: string
    }>
  }>
}

export async function getTipjarPayload(
  chainId: ChainId,
  executor?: StepExecutor,
): Promise<TipjarPayload> {
  const instances = getTipJarInstances(chainId)
  if (instances.length === 0) {
    throw new ArksOverviewError('Unsupported chain or no TipJar deployed', 400)
  }
  const exec = executor ?? createExecutorForChain(chainId)

  const harbor = getHarborCommand(chainId)
  let activeFleets: Address[] = []
  if (harbor) {
    const [harborResult] = await runSettled(exec, [buildActiveFleetsTask(harbor)], DEFAULT_RUN_OPTIONS)
    if (harborResult.status === 'fulfilled' && harborResult.value.fleets !== undefined) {
      activeFleets = harborResult.value.fleets as Address[]
    }
  }

  const [instanceResults, metaResults, pendingResults] = await Promise.all([
    runSettled(exec, instances.map((i) => buildTipJarInstanceTask(i.address)), DEFAULT_RUN_OPTIONS),
    runSettled(exec, activeFleets.map((f) => buildTipJarFleetMetaTask(f)), DEFAULT_RUN_OPTIONS),
    runSettled(
      exec,
      instances.flatMap((inst) => activeFleets.map((f) => buildTipJarPendingTask(inst.address, f))),
      DEFAULT_RUN_OPTIONS,
    ),
  ])

  const fleetCount = activeFleets.length
  const payloadInstances = instances.map((inst, ii) => {
    const instanceReads =
      instanceResults[ii].status === 'fulfilled'
        ? (instanceResults[ii].value as TipJarInstanceReads)
        : ({ streams: undefined, totalAllocation: undefined, paused: undefined } as TipJarInstanceReads)

    const fleets = activeFleets.map((fleetAddress, fi) => {
      const metaRes = metaResults[fi]
      const meta =
        metaRes.status === 'fulfilled'
          ? (metaRes.value as TipJarFleetMetaReads)
          : ({} as TipJarFleetMetaReads)
      const pendingRes = pendingResults[ii * fleetCount + fi]
      const pending =
        pendingRes.status === 'fulfilled'
          ? (pendingRes.value as TipJarPendingReads)
          : ({} as TipJarPendingReads)
      return {
        address: fleetAddress,
        name: meta.name !== undefined ? String(meta.name) : 'Unknown fleet',
        assetSymbol: String(meta.assetSymbol ?? '') || String(meta.symbol ?? ''),
        assetDecimals: meta.assetDecimals !== undefined ? Number(meta.assetDecimals) : 18,
        pendingShares: (pending.pendingShares ?? 0n).toString(),
        pendingAssets: (pending.pendingAssets ?? 0n).toString(),
      }
    })

    return {
      label: inst.label,
      address: inst.address,
      paused: Boolean(instanceReads.paused ?? false),
      totalAllocation: (instanceReads.totalAllocation ?? 0n).toString(),
      streams: (instanceReads.streams ?? []).map((s) => ({
        recipient: s.recipient,
        allocation: s.allocation.toString(),
        lockedUntilEpoch: s.lockedUntilEpoch.toString(),
      })),
      fleets,
    }
  })

  return { chainId, instances: payloadInstances }
}
```

Parity note (accepted, invisible in output): legacy code ran `convertToAssets(0n)` when `balanceOf` failed and reported its result; the graph skip-chains instead and defaults to `'0'` — `convertToAssets(0)` is `0` on every FleetCommander, so the JSON is identical while saving a call.

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm test -- src/lib/domino/tasks/tipjar-task.test.ts`
Expected: PASS.

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 7: Refactor `/api/tipjar` route to the core function

**Files:**
- Modify: `src/app/api/tipjar/route.ts`

**Interfaces:**
- Consumes: `getTipjarPayload` (Task 6); `ArksOverviewError` for status mapping.
- Produces: identical HTTP behavior — 20s TTL cache keyed by chainId, `?refresh=true` bypass, 400 `{ error: 'Unsupported chain or no TipJar deployed' }`, 500 `{ error: message }` on unexpected errors, 200 payload otherwise.

The route becomes a thin wrapper with **no data-fetching logic of its own** — everything it delegates to is already unit-tested in Task 6, so this task's verification is the type-checker, the full test suite, and a manual smoke request (route handlers with `next/server` are deliberately not imported into jest).

- [ ] **Step 1: Rewrite the route**

Replace the body of `src/app/api/tipjar/route.ts` with:

```ts
import { NextResponse } from 'next/server'

import { ArksOverviewError } from '@/lib/arks-overview'
import { getTipjarPayload } from '@/lib/domino/tasks/tipjar-task'
import type { ChainId } from '@/types'

// Pending amounts drift as fees accrue, so keep the cache short. A successful
// shake refetches with `?refresh=true` to bypass it entirely.
const TTL_MS = 20 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const chainId = (url.searchParams.get('chainId') || '1') as ChainId
    const refresh = url.searchParams.get('refresh') === 'true'

    const now = Date.now()
    if (!refresh) {
      const cached = cache.get(chainId)
      if (cached && cached.expiry > now) {
        return NextResponse.json(cached.data)
      }
    }

    const payload = await getTipjarPayload(chainId)
    cache.set(chainId, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
```

Deleted along with the old body: the manual `MULTICALL3_ADDRESS` chain-entity injection (the executor's deployless fallback covers HyperEVM) and all direct viem/ABI imports.

- [ ] **Step 2: Verify**

Run: `pnpm test` → PASS; `pnpm lint` → clean; `npx tsc --noEmit -p tsconfig.json` (or `pnpm build` if faster in practice) → clean.

- [ ] **Step 3: Manual smoke test (record output)**

Run: `pnpm dev` in one terminal, then:

```bash
curl -s 'http://localhost:3000/api/tipjar?chainId=8453&refresh=true' | head -c 2000
```

Expected: 200 JSON with `instances[].streams/fleets` populated. Save the output to compare against the pre-refactor response (capture the "before" JSON on `main` before starting this task — add it to the PR description as the parity evidence).

- [ ] **Step 4: Format**

Run: `pnpm format:fix`

---

### Task 8: Fleet-detail task + `getFleetDetailPayload` core (`fleet-detail-task.ts`)

**Files:**
- Create: `src/lib/domino/tasks/fleet-detail-task.ts`
- Test: `src/lib/domino/tasks/fleet-detail-task.test.ts`

**Interfaces:**
- Consumes: Tasks 1–2; `ArksOverviewError`.
- Produces (consumed by Task 9):
  - `buildFleetDetailTask(fleet: Address, user: Address | null): MultistepTask<FleetDetailReads>` — fleet reads + asset reads via ref target + (when `user`) `balanceOf(user)` on fleet, `balanceOf(user)` and `allowance(user, fleet)` on the asset ref.
  - `getFleetDetailPayload(chainId: string, address: string, user: string | null, executor?: StepExecutor)` — returns the legacy payload object; throws `ArksOverviewError` with exactly: `('Unsupported chainId', 400)`, `('Failed to read fleet contract', 502)`, `('Failed to read asset contract', 502)`, `('Failed to read user info', 502)`.

- [ ] **Step 1: Write the failing test**

Create `src/lib/domino/tasks/fleet-detail-task.test.ts`:

```ts
import { callKey, FAIL, MockStepExecutor } from '../testing/mock-executor'
import { getFleetDetailPayload } from './fleet-detail-task'

const FLEET = '0xf1Ee7000000000000000000000000000000000F1' as const
const ASSET = '0xA55E7000000000000000000000000000000000A5' as const
const USER = '0x0000000000000000000000000000000000000009' as const

const handlers = {
  [callKey(FLEET, 'name')]: 'Fleet One',
  [callKey(FLEET, 'symbol')]: 'FL1',
  [callKey(FLEET, 'asset')]: ASSET,
  [callKey(FLEET, 'totalAssets')]: 12345n,
  [callKey(FLEET, 'withdrawableTotalAssets')]: 12000n,
  [callKey(FLEET, 'decimals')]: 18,
  [callKey(FLEET, 'getConfig')]: {
    bufferArk: '0x0000000000000000000000000000000000000002',
    minimumBufferBalance: 100n,
    depositCap: 9000n,
    maxRebalanceOperations: 4n,
    stakingRewardsManager: '0x0000000000000000000000000000000000000003',
  },
  [callKey(ASSET, 'decimals')]: 6,
  [callKey(ASSET, 'symbol')]: 'USDC',
  [callKey(FLEET, 'balanceOf')]: 111n,
  [callKey(ASSET, 'balanceOf')]: 222n,
  [callKey(ASSET, 'allowance')]: 333n,
}

describe('getFleetDetailPayload', () => {
  it('throws 400 for an unsupported chainId', async () => {
    await expect(
      getFleetDetailPayload('42', FLEET, null, new MockStepExecutor(handlers)),
    ).rejects.toMatchObject({ message: 'Unsupported chainId', status: 400 })
  })

  it('returns the legacy payload without user info', async () => {
    const payload = await getFleetDetailPayload('8453', FLEET, null, new MockStepExecutor(handlers))
    expect(payload).toEqual({
      address: FLEET,
      name: 'Fleet One',
      symbol: 'FL1',
      asset: ASSET,
      totalAssets: '12345',
      withdrawableTotalAssets: '12000',
      depositCap: '9000',
      minimumBufferBalance: '100',
      maxRebalanceOperations: '4',
      assetDecimals: 6,
      assetSymbol: 'USDC',
      fleetDecimals: 18,
      userInfo: null,
    })
  })

  it('includes userInfo when a user is given', async () => {
    const payload = await getFleetDetailPayload('8453', FLEET, USER, new MockStepExecutor(handlers))
    expect(payload.userInfo).toEqual({
      balance: '111',
      underlyingBalance: '222',
      allowance: '333',
    })
  })

  it('maps failures to the three legacy 502 errors', async () => {
    await expect(
      getFleetDetailPayload('8453', FLEET, null, new MockStepExecutor({ ...handlers, [callKey(FLEET, 'name')]: FAIL })),
    ).rejects.toMatchObject({ message: 'Failed to read fleet contract', status: 502 })
    await expect(
      getFleetDetailPayload('8453', FLEET, null, new MockStepExecutor({ ...handlers, [callKey(ASSET, 'decimals')]: FAIL })),
    ).rejects.toMatchObject({ message: 'Failed to read asset contract', status: 502 })
    await expect(
      getFleetDetailPayload('8453', FLEET, USER, new MockStepExecutor({ ...handlers, [callKey(ASSET, 'allowance')]: FAIL })),
    ).rejects.toMatchObject({ message: 'Failed to read user info', status: 502 })
  })
})
```

Note: `getFleetDetailPayload` must `getAddress`-normalize `address` exactly like the current route (`FLEET` above is deliberately mixed-case to exercise this).

- [ ] **Step 2: Run test to verify it fails**

Run: `pnpm test -- src/lib/domino/tasks/fleet-detail-task.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Write the implementation**

Create `src/lib/domino/tasks/fleet-detail-task.ts`:

```ts
import { defineTask, runSettled, type MultistepTask, type StepExecutor } from '@halaprix/domino'
import { getAddress } from 'viem'

import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { CHAIN_RPC_URLS } from '@/config/chains'
import { ArksOverviewError } from '@/lib/arks-overview'
import { createExecutorForChain, DEFAULT_RUN_OPTIONS } from '@/lib/domino/executor'

type Address = `0x${string}`

export interface FleetDetailReads {
  name: string | undefined
  symbol: string | undefined
  asset: Address | undefined
  totalAssets: bigint | undefined
  withdrawableTotalAssets: bigint | undefined
  fleetDecimals: number | undefined
  config: unknown
  assetDecimals: number | undefined
  assetSymbol: string | undefined
  userBalance: bigint | undefined
  userUnderlyingBalance: bigint | undefined
  userAllowance: bigint | undefined
}

export function buildFleetDetailTask(
  fleet: Address,
  user: Address | null,
): MultistepTask<FleetDetailReads> {
  return defineTask((t) => {
    const asset = t.call({
      target: fleet,
      abi: fleetCommanderAbi,
      functionName: 'asset',
      optional: true,
    })
    return {
      name: t.call({ target: fleet, abi: fleetCommanderAbi, functionName: 'name', optional: true }),
      symbol: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'symbol',
        optional: true,
      }),
      asset,
      totalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'totalAssets',
        optional: true,
      }),
      withdrawableTotalAssets: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'withdrawableTotalAssets',
        optional: true,
      }),
      fleetDecimals: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'decimals',
        optional: true,
      }),
      config: t.call({
        target: fleet,
        abi: fleetCommanderAbi,
        functionName: 'getConfig',
        optional: true,
      }),
      assetDecimals: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'decimals',
        optional: true,
      }),
      assetSymbol: t.call({
        target: asset as never,
        abi: erc20Abi,
        functionName: 'symbol',
        optional: true,
      }),
      userBalance: user
        ? t.call({
            target: fleet,
            abi: fleetCommanderAbi,
            functionName: 'balanceOf',
            args: [user],
            optional: true,
          })
        : undefined,
      userUnderlyingBalance: user
        ? t.call({
            target: asset as never,
            abi: erc20Abi,
            functionName: 'balanceOf',
            args: [user],
            optional: true,
          })
        : undefined,
      userAllowance: user
        ? t.call({
            target: asset as never,
            abi: erc20Abi,
            functionName: 'allowance',
            args: [user, fleet],
            optional: true,
          })
        : undefined,
    } as unknown as FleetDetailReads
  }) as MultistepTask<FleetDetailReads>
}

export interface FleetDetailPayload {
  address: string
  name: string
  symbol: string
  asset: Address
  totalAssets: string
  withdrawableTotalAssets: string
  depositCap: string
  minimumBufferBalance: string
  maxRebalanceOperations: string
  assetDecimals: number
  assetSymbol: string
  fleetDecimals: number
  userInfo: { balance: string; underlyingBalance: string; allowance: string } | null
}

export async function getFleetDetailPayload(
  chainId: string,
  address: string,
  user: string | null,
  executor?: StepExecutor,
): Promise<FleetDetailPayload> {
  const rpcUrls = CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]
  if (!rpcUrls) throw new ArksOverviewError('Unsupported chainId', 400)
  const exec = executor ?? createExecutorForChain(chainId)
  const fleetAddr = getAddress(address)

  const [result] = await runSettled(
    exec,
    [buildFleetDetailTask(fleetAddr, (user as Address | null) ?? null)],
    DEFAULT_RUN_OPTIONS,
  )
  if (result.status === 'rejected') {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  const reads = result.value as FleetDetailReads

  if (
    reads.name === undefined ||
    reads.symbol === undefined ||
    reads.asset === undefined ||
    reads.totalAssets === undefined ||
    reads.withdrawableTotalAssets === undefined ||
    reads.fleetDecimals === undefined ||
    reads.config === undefined
  ) {
    throw new ArksOverviewError('Failed to read fleet contract', 502)
  }
  if (reads.assetDecimals === undefined || reads.assetSymbol === undefined) {
    throw new ArksOverviewError('Failed to read asset contract', 502)
  }

  let userInfo: FleetDetailPayload['userInfo'] = null
  if (user) {
    if (
      reads.userBalance === undefined ||
      reads.userUnderlyingBalance === undefined ||
      reads.userAllowance === undefined
    ) {
      throw new ArksOverviewError('Failed to read user info', 502)
    }
    userInfo = {
      balance: reads.userBalance.toString(),
      underlyingBalance: reads.userUnderlyingBalance.toString(),
      allowance: reads.userAllowance.toString(),
    }
  }

  const config = reads.config as {
    bufferArk: Address
    minimumBufferBalance: bigint
    depositCap: bigint
    maxRebalanceOperations: bigint
    stakingRewardsManager: Address
  }

  return {
    address,
    name: String(reads.name),
    symbol: String(reads.symbol),
    asset: reads.asset,
    totalAssets: reads.totalAssets.toString(),
    withdrawableTotalAssets: reads.withdrawableTotalAssets.toString(),
    depositCap: config.depositCap.toString(),
    minimumBufferBalance: config.minimumBufferBalance.toString(),
    maxRebalanceOperations: config.maxRebalanceOperations.toString(),
    assetDecimals: Number(reads.assetDecimals),
    assetSymbol: String(reads.assetSymbol),
    fleetDecimals: Number(reads.fleetDecimals),
    userInfo,
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pnpm test -- src/lib/domino/tasks/fleet-detail-task.test.ts`
Expected: PASS.

- [ ] **Step 5: Format**

Run: `pnpm format:fix`

---

### Task 9: Refactor `/api/fleets/[chainId]/[address]` route

**Files:**
- Modify: `src/app/api/fleets/[chainId]/[address]/route.ts`

**Interfaces:**
- Consumes: `getFleetDetailPayload`, `ArksOverviewError`.
- Produces: identical HTTP behavior — 30s TTL cache keyed `${chainId}:${address}:${user ?? ''}`, same status codes/messages.

- [ ] **Step 1: Rewrite the route**

Replace the file body with:

```ts
import { NextResponse } from 'next/server'

import { ArksOverviewError } from '@/lib/arks-overview'
import { getFleetDetailPayload } from '@/lib/domino/tasks/fleet-detail-task'

const TTL_MS = 30 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  request: Request,
  { params }: { params: Promise<{ chainId: string; address: string }> },
) {
  const { chainId, address } = await params
  const url = new URL(request.url)
  const user = url.searchParams.get('user')
  const key = `${chainId}:${address}:${user ?? ''}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  try {
    const payload = await getFleetDetailPayload(chainId, address, user)
    cache.set(key, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload)
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
```

Behavioral note (accepted improvement): the legacy route let unexpected errors (e.g. `getAddress` on a malformed address) escape as an unhandled 500 from Next; this catch returns a structured 500 with the same status code.

- [ ] **Step 2: Verify**

Run: `pnpm test` → PASS; `pnpm lint` → clean.

- [ ] **Step 3: Manual smoke test (record output)**

With `pnpm dev` running, request a real fleet (use one from the arks-overview UI) with and without `?user=`; diff against the same requests captured on `main`.

- [ ] **Step 4: Format**

Run: `pnpm format:fix`

---

### Task 10: Final verification & parity evidence

**Files:** none (verification only)

- [ ] **Step 1: Full quality gates**

```bash
pnpm test
pnpm lint
pnpm build
```

Expected: all green. `pnpm build` is the real gate for the route files (they are not imported into jest).

- [ ] **Step 2: Response-parity diff**

For each endpoint, diff live responses between a `main` checkout and this branch (same block-ish timing; TVL fields may drift between calls — compare key sets and value formats, and exact values for static fields):

```bash
curl -s 'http://localhost:3000/api/tipjar?chainId=8453&refresh=true' | jq -S 'del(.. | .totalAllocation?)' > after-tipjar.json
curl -s 'http://localhost:3000/api/fleets/8453/<FLEET>?user=<USER>' | jq -S . > after-fleet.json
# repeat on main -> before-*.json ; then:
diff before-tipjar.json after-tipjar.json
```

Expected: no structural differences. Attach to the PR.

- [ ] **Step 3: Latency benchmark (informational)**

```bash
for i in 1 2 3; do curl -s -o /dev/null -w '%{time_total}\n' 'http://localhost:3000/api/tipjar?chainId=8453&refresh=true'; done
```

Record before/after medians in the PR description. Expected direction: tipjar ~6 sequential stages → ~2 effective stages; per-fleet arks 4 stages → 3.

- [ ] **Step 4: Leftover-scope check**

Confirm `src/lib/arks-overview.ts` no longer imports `createPublicClient` and that no `@ts-ignore - viem multicall` comments remain in the three refactored files:

```bash
grep -rn 'client.multicall\|@ts-ignore - viem multicall\|@ts-expect-error - viem multicall' src/lib/arks-overview.ts src/app/api/tipjar/route.ts 'src/app/api/fleets/[chainId]/[address]/route.ts'
```

Expected: no matches.

---

## Non-Goals & Constraints (carried over from v1)

- **No UI breaking changes** — components/hooks consuming these endpoints need zero changes.
- **No automated git commits** — the executing agent leaves the working tree for human review.
- **`MultichainResolver` / `pinBlock` adoption** — out of scope (see Validation notes #4); revisit once the single-chain layer has soaked.
