'use client'

import { useQuery } from '@tanstack/react-query'

import { useAppEnvironment } from '@/components/env/AppEnvironmentProvider'
import { gqlFetch } from '@/lib/subgraph/client'
import { ROLES_FOR_INSTITUTION } from '@/lib/subgraph/queries/roles'
import type { SubgraphRole } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

interface Response {
  institution: { id: string; roles: SubgraphRole[] } | null
}

export function useRolesForInstitution(institutionId: string, chainId: ChainId) {
  const env = useAppEnvironment()
  const query = useQuery({
    queryKey: ['institution-roles', env, chainId, institutionId],
    enabled: !!institutionId,
    queryFn: async () => {
      const data = await gqlFetch<Response>(chainId, env, ROLES_FOR_INSTITUTION, {
        institutionId: institutionId.toLowerCase(),
      })
      return data.institution?.roles ?? []
    },
    staleTime: 30_000,
  })
  return {
    roles: query.data ?? [],
    loading: query.isLoading,
    error: query.error as Error | null,
    refetch: query.refetch,
  }
}
