import { useQuery } from '@tanstack/react-query'

import type { ChainId } from '../types'

interface RoleEvent {
  id: string
  hash: string
  logIndex: number
  timestamp: string
  blockNumber: string
  caller: string
  action: string
}

interface Role {
  id: string
  name: string
  owner: string
  targetContract: string
  accessController: string
  active: boolean
  createdTimestamp: string
  createdBlockNumber: string
  events: RoleEvent[]
}

interface UseRolesResponse {
  chainId: ChainId
  roles: Role[]
}

interface UseRolesProps {
  chainId: ChainId
  activeOnly?: boolean
}

export function useRoles({ chainId, activeOnly = false }: UseRolesProps) {
  return useQuery<UseRolesResponse>({
    queryKey: ['roles', chainId, activeOnly],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (activeOnly) {
        params.set('activeOnly', 'true')
      }
      const response = await fetch(`/api/roles/${chainId}?${params.toString()}`)
      if (!response.ok) {
        throw new Error('Failed to fetch roles')
      }
      return response.json()
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  })
}
