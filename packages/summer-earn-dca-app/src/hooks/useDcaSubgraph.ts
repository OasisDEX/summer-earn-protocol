'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'

import { gqlFetch } from '@/lib/subgraph/client'
import {
  EXECUTIONS_BY_STRATEGY,
  STRATEGIES_BY_OWNER,
  STRATEGY_BY_ID,
} from '@/lib/subgraph/queries'
import type { SubgraphExecution, SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

export function useStrategiesByOwner(chainId: ChainId, owner: Address | undefined) {
  return useQuery({
    queryKey: ['dca', 'strategies', chainId, owner?.toLowerCase()],
    enabled: Boolean(owner),
    queryFn: async () => {
      const data = await gqlFetch<{ strategies: SubgraphStrategy[] }>(
        chainId,
        STRATEGIES_BY_OWNER,
        { owner: owner!.toLowerCase(), first: 50, skip: 0 },
      )
      return data.strategies
    },
  })
}

export function useStrategyById(chainId: ChainId, strategyId: string | undefined) {
  return useQuery({
    queryKey: ['dca', 'strategy', chainId, strategyId],
    enabled: Boolean(strategyId),
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
