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
