'use client'

import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { Address } from 'viem'

import { gqlFetch } from '@/lib/subgraph/client'
import { EXECUTIONS_BY_STRATEGY, STRATEGIES_BY_OWNER, STRATEGY_BY_ID } from '@/lib/subgraph/queries'
import type { SubgraphExecution, SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export function useStrategiesByOwner(chainId: ChainId, owner: Address | undefined) {
  const queryClient = useQueryClient()
  return useQuery({
    queryKey: ['dca', 'strategies', chainId, owner?.toLowerCase()],
    enabled: Boolean(owner),
    // Portfolio data is cheap to keep around — a 30s staleTime stops
    // re-fetching on every navigation back to the list.
    staleTime: 30_000,
    queryFn: async () => {
      const data = await gqlFetch<{ strategies: SubgraphStrategy[] }>(
        chainId,
        STRATEGIES_BY_OWNER,
        { owner: owner!.toLowerCase(), first: 50, skip: 0 },
      )
      // Seed individual STRATEGY_BY_ID cache entries so that clicking through
      // to the detail page renders the row from cache synchronously and the
      // price-history queries can fire on the first render instead of after
      // the subgraph round-trip. The fresh STRATEGY_BY_ID fetch (which asks
      // for more executions than the list query embeds) still runs in the
      // background and reconciles.
      for (const s of data.strategies) {
        queryClient.setQueryData(['dca', 'strategy', chainId, s.id], s)
      }
      return data.strategies
    },
  })
}

export function useStrategyById(chainId: ChainId, strategyId: string | undefined) {
  const queryClient = useQueryClient()
  return useQuery<SubgraphStrategy | null>({
    queryKey: ['dca', 'strategy', chainId, strategyId],
    enabled: Boolean(strategyId),
    staleTime: 30_000,
    // If the user came from the portfolio, the entity is already in the
    // strategies-by-owner cache. Pull it forward so the detail page renders
    // with data on the first paint while the fresh fetch refines it.
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

export function useExecutionsByStrategy(
  chainId: ChainId,
  strategyId: string | undefined,
  first = 25,
  skip = 0,
) {
  return useQuery({
    queryKey: ['dca', 'executions', chainId, strategyId, first, skip],
    enabled: Boolean(strategyId),
    queryFn: async () => {
      const data = await gqlFetch<{ executions: SubgraphExecution[] }>(
        chainId,
        EXECUTIONS_BY_STRATEGY,
        { strategyId: strategyId!, first, skip },
      )
      return data.executions
    },
  })
}
