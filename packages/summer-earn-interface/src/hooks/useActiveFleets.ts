'use client'

import { useQuery } from '@tanstack/react-query'

import type { Environment } from '@/config/environments'
import type { FleetCommanderInfo } from '@/types'

interface UseActiveFleetsProps {
  chainId: string
  environment: Environment
}

type FleetApiEntry = {
  address: string
  name: string
  symbol: string
  asset: string
  totalAssets: string
  withdrawableTotalAssets: string
  depositCap?: string | null
  minimumBufferBalance?: string | null
  maxRebalanceOperations?: string | null
  assetDecimals: number | string
  assetSymbol: string
  fleetDecimals?: number | string | null
}

type FleetsApiResponse = {
  fleets: FleetApiEntry[]
}

export function useActiveFleets({ chainId, environment }: UseActiveFleetsProps) {
  const query = useQuery({
    queryKey: ['fleets', chainId, environment],
    queryFn: async () => {
      const res = await fetch(
        `/api/fleets?chainId=${encodeURIComponent(chainId)}&environment=${encodeURIComponent(environment)}`,
        { cache: 'no-store' },
      )
      if (!res.ok) throw new Error(`Failed to load fleets: ${res.status}`)
      const data = (await res.json()) as FleetsApiResponse
      const fleets: FleetCommanderInfo[] = data.fleets.map((fleet) => ({
        address: fleet.address,
        name: fleet.name,
        symbol: fleet.symbol,
        asset: fleet.asset,
        totalAssets: BigInt(fleet.totalAssets),
        withdrawableTotalAssets: BigInt(fleet.withdrawableTotalAssets),
        depositCap: BigInt(fleet.depositCap ?? '0'),
        assetDecimals: Number(fleet.assetDecimals),
        assetSymbol: String(fleet.assetSymbol),
        fleetDecimals: Number(fleet.fleetDecimals ?? fleet.assetDecimals),
        minimumBufferBalance: BigInt(fleet.minimumBufferBalance ?? '0'),
        maxRebalanceOperations: BigInt(fleet.maxRebalanceOperations ?? '50'),
      }))
      return fleets
    },
    staleTime: 10 * 60 * 1000,
    refetchOnWindowFocus: false,
  })

  return {
    fleets: query.data ?? [],
    loading: query.isLoading,
    error: (query.error as Error) ?? null,
  }
}
