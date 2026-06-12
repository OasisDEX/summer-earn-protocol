'use client'

import { useQuery } from '@tanstack/react-query'

import { useAppEnvironment } from '@/components/env/AppEnvironmentProvider'
import { gqlFetch } from '@/lib/subgraph/client'
import { ROUNDS_VAULT_WITH_RECENT_ROUNDS } from '@/lib/subgraph/queries/rounds'
import type { SubgraphRoundsVault } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface UseRoundsProps {
  roundsVaultAddress: `0x${string}`
  chainId: ChainId
  first?: number
  initialData?: SubgraphRoundsVault | null
}

interface Response {
  roundsVault: SubgraphRoundsVault | null
}

export function useRounds({
  roundsVaultAddress,
  chainId,
  first = 30,
  initialData,
}: UseRoundsProps) {
  const env = useAppEnvironment()
  const query = useQuery({
    queryKey: ['rounds', env, chainId, roundsVaultAddress, first],
    initialData: initialData ?? undefined,
    queryFn: async () => {
      const data = await gqlFetch<Response>(chainId, env, ROUNDS_VAULT_WITH_RECENT_ROUNDS, {
        id: roundsVaultAddress.toLowerCase(),
        first,
      })
      return data.roundsVault
    },
    staleTime: 15_000,
    refetchInterval: 30_000,
  })
  return {
    roundsVault: query.data ?? null,
    rounds: query.data?.rounds ?? [],
    loading: query.isLoading,
    error: query.error as Error | null,
    refetch: query.refetch,
  }
}
