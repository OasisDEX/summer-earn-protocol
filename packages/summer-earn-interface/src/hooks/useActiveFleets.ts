"use client"

import { useQuery } from "@tanstack/react-query"
import type { Environment } from "@/config/environments"
import type { FleetCommanderInfo } from "@/types"

interface UseActiveFleetsProps {
  chainId: string
  environment: Environment
}

export function useActiveFleets({ chainId, environment }: UseActiveFleetsProps) {
  const query = useQuery({
    queryKey: ["fleets", chainId, environment],
    queryFn: async () => {
      const res = await fetch(
        `/api/fleets?chainId=${encodeURIComponent(chainId)}&environment=${encodeURIComponent(environment)}`,
        { cache: "no-store" },
      )
      if (!res.ok) throw new Error(`Failed to load fleets: ${res.status}`)
      const data = (await res.json()) as { fleets: any[] }
      const fleets: FleetCommanderInfo[] = data.fleets.map((f) => ({
        address: f.address,
        name: f.name,
        symbol: f.symbol,
        asset: f.asset,
        totalAssets: BigInt(f.totalAssets),
        withdrawableTotalAssets: BigInt(f.withdrawableTotalAssets),
        depositCap: BigInt(f.depositCap ?? "0"),
        assetDecimals: Number(f.assetDecimals),
        assetSymbol: String(f.assetSymbol),
        fleetDecimals: Number(f.fleetDecimals ?? f.assetDecimals),
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
