'use client'

import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { useBlockNumber, useReadContract } from 'wagmi'

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

// RPC read of `strategyStates(id)`. Re-queries on each new block so that
// post-execution state reflects in the UI within ~1 block on Base.
export function useStrategyState(chainId: ChainId, strategyId: bigint | undefined) {
  const queryClient = useQueryClient()
  const enabled = strategyId !== undefined

  const read = useReadContract({
    chainId: Number(chainId),
    address: DCA_STRATEGY_MANAGER_ADDRESSES[chainId],
    abi: dcaStrategyManagerAbi,
    functionName: 'strategyStates',
    args: enabled ? [strategyId!] : undefined,
    query: { enabled },
  })

  const { data: blockNumber } = useBlockNumber({ chainId: Number(chainId), watch: true })

  useEffect(() => {
    if (!enabled || !blockNumber) return
    if (read.queryKey) {
      queryClient.invalidateQueries({ queryKey: read.queryKey })
    }
  }, [blockNumber, enabled, queryClient, read.queryKey])

  return {
    state: toTyped(read.data as RawState | undefined),
    isLoading: read.isLoading,
    isError: read.isError,
    refetch: read.refetch,
  }
}
