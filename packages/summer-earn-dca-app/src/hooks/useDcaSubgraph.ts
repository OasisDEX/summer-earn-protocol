'use client'

import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { Address } from 'viem'

import { gqlFetch } from '@/lib/subgraph/client'
import {
  EXECUTIONS_BY_STRATEGY_FIRST,
  EXECUTIONS_BY_STRATEGY_NEXT,
  STRATEGIES_BY_OWNER_FIRST,
  STRATEGY_BY_ID,
} from '@/lib/subgraph/queries'
import type { SubgraphExecution, SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export function useStrategiesByOwner(
  chainId: ChainId,
  owner: Address | undefined,
  initialData?: SubgraphStrategy[],
) {
  const queryClient = useQueryClient()
  // Seed per-id cache entries so child StrategyCards find them on first
  // render and clicking through to /strategy/[id] is instant.
  if (initialData) {
    for (const s of initialData) {
      queryClient.setQueryData(['dca', 'strategy', chainId, s.id], s)
    }
  }
  return useQuery({
    queryKey: ['dca', 'strategies', chainId, owner?.toLowerCase()],
    enabled: Boolean(owner),
    staleTime: 30_000,
    initialData,
    queryFn: async () => {
      const data = await gqlFetch<{ strategies: SubgraphStrategy[] }>(
        chainId,
        STRATEGIES_BY_OWNER_FIRST,
        { owner: owner!.toLowerCase(), first: 50 },
      )
      for (const s of data.strategies) {
        queryClient.setQueryData(['dca', 'strategy', chainId, s.id], s)
      }
      return data.strategies
    },
  })
}

export function useStrategyById(
  chainId: ChainId,
  strategyId: string | undefined,
  initialData?: SubgraphStrategy | null,
) {
  const queryClient = useQueryClient()
  return useQuery<SubgraphStrategy | null>({
    queryKey: ['dca', 'strategy', chainId, strategyId],
    enabled: Boolean(strategyId),
    staleTime: 30_000,
    initialData: initialData ?? undefined,
    // Fallback for the portfolio → detail click-through path: scan any
    // cached strategies-by-owner list for the matching row.
    placeholderData: () => {
      if (!strategyId) return undefined
      const lists = queryClient.getQueriesData<SubgraphStrategy[]>({
        queryKey: ['dca', 'strategies', chainId],
      })
      for (const [, list] of lists) {
        const hit = list?.find((s) => s.id === strategyId)
        if (hit) return hit
      }
      return undefined
    },
    queryFn: async () => {
      const data = await gqlFetch<{ strategy: SubgraphStrategy | null }>(chainId, STRATEGY_BY_ID, {
        id: strategyId!,
        executionsFirst: 50,
      })
      return data.strategy
    },
  })
}

// Cursor-paginated: pass the oldest `executionTimestamp` to fetch the next page.
export function useExecutionsByStrategy(
  chainId: ChainId,
  strategyId: string | undefined,
  first = 25,
  cursorExecutionTimestamp?: string,
) {
  return useQuery({
    queryKey: ['dca', 'executions', chainId, strategyId, first, cursorExecutionTimestamp ?? null],
    enabled: Boolean(strategyId),
    queryFn: async () => {
      const data = cursorExecutionTimestamp
        ? await gqlFetch<{ executions: SubgraphExecution[] }>(
            chainId,
            EXECUTIONS_BY_STRATEGY_NEXT,
            { strategyId: strategyId!, first, cursorExecutionTimestamp },
          )
        : await gqlFetch<{ executions: SubgraphExecution[] }>(
            chainId,
            EXECUTIONS_BY_STRATEGY_FIRST,
            { strategyId: strategyId!, first },
          )
      return data.executions
    },
  })
}
