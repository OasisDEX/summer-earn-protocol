'use client'

import { useQuery } from '@tanstack/react-query'

import { ArkInfo } from '../types'

interface UseFleetArksProps {
  fleetAddress: `0x${string}`
  chainId: string
}

// Retained for historical context; no longer used after API move

export function useFleetArks({ fleetAddress, chainId }: UseFleetArksProps) {
  const query = useQuery({
    queryKey: ['arks', chainId, fleetAddress],
    queryFn: async () => {
      const res = await fetch(`/api/fleets/${encodeURIComponent(chainId)}/${fleetAddress}/arks`)
      if (!res.ok) throw new Error(`Failed to load arks: ${res.status}`)
      const data = (await res.json()) as Array<{
        address: string
        totalAssets: string
        withdrawableTotalAssets: string
        name: string
        isBufferArk?: boolean
      }>
      const arks: ArkInfo[] = data.map((a) => ({
        address: a.address,
        totalAssets: BigInt(a.totalAssets),
        withdrawableTotalAssets: BigInt(a.withdrawableTotalAssets),
        name: a.name,
        isBufferArk: a.isBufferArk,
      }))
      // Ensure buffer ark first
      return arks.sort((a, b) => (a.isBufferArk === b.isBufferArk ? 0 : a.isBufferArk ? -1 : 1))
    },
    staleTime: 10 * 60 * 1000,
    refetchOnWindowFocus: false,
    enabled: !!fleetAddress,
  })

  return {
    arks: query.data ?? [],
    loading: query.isLoading,
    error: (query.error as Error) ?? null,
  }
}
