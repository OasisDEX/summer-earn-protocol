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
  // Seed per-id entries from initialData at hook construction so that any
  // child <StrategyCard> mounting on the first render already finds the
  // entity in cache. Doing it here (instead of inside queryFn) means the
  // server-delivered list also primes the detail-page cache before the
  // user clicks through.
  if (initialData) {
    for (const s of initialData) {
      queryClient.setQueryData(['dca', 'strategy', chainId, s.id], s)
    }
  }
  return useQuery({
    queryKey: ['dca', 'strategies', chainId, owner?.toLowerCase()],
    enabled: Boolean(owner),
    // Portfolio data is cheap to keep around — a 30s staleTime stops
    // re-fetching on every navigation back to the list.
    staleTime: 30_000,
    initialData,
    queryFn: async () => {
      // First page only — use STRATEGIES_BY_OWNER_NEXT with the oldest
      // returned `createdAt` if pagination is ever wired in.
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
    // Server-side loader can pass the row down with the HTML; use it as
    // `initialData` so first render has the entity in hand without any
    // client fetch. Fallback to scanning the strategies-by-owner cache for
    // the portfolio → detail click-through path.
    initialData: initialData ?? undefined,
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

// Cursor-paginated. Pass the oldest `executionTimestamp` returned so far as
// `cursorExecutionTimestamp` to fetch the next page; leave undefined for
// the first page.
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
