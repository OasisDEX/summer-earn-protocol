'use client'

import { useReadContract } from 'wagmi'

import { dcaStrategyManagerAbi } from '@/abis/DCAStrategyManager'
import { DCA_STRATEGY_MANAGER_ADDRESSES } from '@/config/addresses'
import type { ChainId } from '@/types/chain'
import { type StrategyStateOnchain, StrategyStatus } from '@/types/strategy'

interface RawState {
  status: number
  tradesExecuted: bigint
  nextTriggerAt: bigint
  lastScheduledAt: bigint
}

function toTyped(raw: RawState | undefined): StrategyStateOnchain | undefined {
  if (!raw) return undefined
  return {
    status: raw.status as StrategyStatus,
    tradesExecuted: raw.tradesExecuted,
    nextTriggerAt: raw.nextTriggerAt,
    lastScheduledAt: raw.lastScheduledAt,
  }
}

// RPC read of `strategyStates(id)`. Polled lazily on a 30s cadence — user
// actions are already invalidated by useTxToast at confirmation time, and
// external keeper executions surface via the subgraph in seconds. Avoid
// per-block invalidation: with N visible StrategyCard instances it produces
// an N-read multicall every Base block (~2s) which is wasteful for state
// that changes at most once per interval (≥ 1 day).
//
// `initialState` is optional — pre-resolved value from a server component
// loader, used as TanStack `initialData` so first render doesn't need a
// client RPC round-trip. Polling kicks in immediately after hydration.
export function useStrategyState(
  chainId: ChainId,
  strategyId: bigint | undefined,
  initialState?: StrategyStateOnchain | null,
) {
  const enabled = strategyId !== undefined

  const read = useReadContract({
    chainId: Number(chainId),
    address: DCA_STRATEGY_MANAGER_ADDRESSES[chainId],
    abi: dcaStrategyManagerAbi,
    functionName: 'strategyStates',
    args: enabled ? [strategyId!] : undefined,
    query: {
      enabled,
      // Background poll while the page is open; foreground reads will hit
      // the cache. 30s is well under the contract's 1-day minimum interval.
      refetchInterval: 30_000,
      staleTime: 30_000,
      initialData: initialState
        ? {
            status: initialState.status,
            tradesExecuted: initialState.tradesExecuted,
            nextTriggerAt: initialState.nextTriggerAt,
            lastScheduledAt: initialState.lastScheduledAt,
          }
        : undefined,
    },
  })

  return {
    state: toTyped(read.data as RawState | undefined),
    isLoading: read.isLoading,
    isError: read.isError,
    refetch: read.refetch,
  }
}
