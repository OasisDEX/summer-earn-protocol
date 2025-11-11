'use client'

import { useQuery } from '@tanstack/react-query'

import type { ChainId } from '@/types'
import type { Institution, RoleEntity, VaultEntity } from '@/types/subgraph'

export const useInstitutions = (chainId: ChainId) => {
  return useQuery({
    queryKey: ['institutions', chainId],
    queryFn: async (): Promise<Institution[]> => {
      const res = await fetch(`/api/institutions?chainId=${encodeURIComponent(chainId)}`, {
        cache: 'no-store',
      })
      if (!res.ok) throw new Error(`Failed to load institutions: ${res.status}`)
      const data = await res.json()
      return (data.institutions ?? []) as Institution[]
    },
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}

export const useInstitutionRoles = (chainId: ChainId, institutionId?: string) => {
  return useQuery({
    queryKey: ['institution-roles', chainId, institutionId],
    queryFn: async (): Promise<RoleEntity[]> => {
      const res = await fetch(
        `/api/institutions/${encodeURIComponent(institutionId ?? '')}/roles?chainId=${encodeURIComponent(chainId)}`,
        { cache: 'no-store' },
      )
      if (!res.ok) throw new Error(`Failed to load roles: ${res.status}`)
      const data = await res.json()
      return (data.roles ?? []) as RoleEntity[]
    },
    enabled: !!institutionId,
    staleTime: 0,
    refetchOnWindowFocus: false,
  })
}

export const useInstitutionVaults = (chainId: ChainId, institutionId?: string) => {
  return useQuery({
    queryKey: ['institution-vaults', chainId, institutionId],
    queryFn: async (): Promise<VaultEntity[]> => {
      const res = await fetch(
        `/api/institutions/${encodeURIComponent(institutionId ?? '')}/vaults?chainId=${encodeURIComponent(chainId)}`,
        { cache: 'no-store' },
      )
      if (!res.ok) throw new Error(`Failed to load vaults: ${res.status}`)
      const data = await res.json()
      return (data.vaults ?? []) as VaultEntity[]
    },
    enabled: !!institutionId,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  })
}
