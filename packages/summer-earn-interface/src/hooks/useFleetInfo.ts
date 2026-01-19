'use client'

import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useAccount } from 'wagmi'

import { FleetCommanderInfo, UserFleetInfo } from '../types'

interface UseFleetInfoProps {
  address: `0x${string}`
  chainId: string
}

export function useFleetInfo({ address, chainId }: UseFleetInfoProps) {
  const { address: userAddress, isConnected } = useAccount()
  const queryClient = useQueryClient()

  const query = useQuery({
    queryKey: ['fleetInfo', chainId, address, isConnected ? userAddress : undefined],
    queryFn: async () => {
      const qs = new URLSearchParams()
      if (isConnected && userAddress) qs.set('user', userAddress)
      const res = await fetch(
        `/api/fleets/${encodeURIComponent(chainId)}/${address}?${qs.toString()}`,
      )
      if (!res.ok) throw new Error(`Failed to load fleet info: ${res.status}`)
      const data = await res.json()
      const fleet: FleetCommanderInfo = {
        address: data.address,
        name: data.name,
        symbol: data.symbol,
        asset: data.asset,
        totalAssets: BigInt(data.totalAssets),
        withdrawableTotalAssets: BigInt(data.withdrawableTotalAssets),
        depositCap: BigInt(data.depositCap ?? '0'),
        minimumBufferBalance: BigInt(data.minimumBufferBalance ?? '0'),
        maxRebalanceOperations: BigInt(data.maxRebalanceOperations ?? '50'),
        assetDecimals: Number(data.assetDecimals),
        assetSymbol: String(data.assetSymbol),
        fleetDecimals: Number(data.fleetDecimals ?? data.assetDecimals),
      }
      const user: UserFleetInfo | null = data.userInfo
        ? {
            balance: BigInt(data.userInfo.balance),
            underlyingBalance: BigInt(data.userInfo.underlyingBalance),
            allowance: BigInt(data.userInfo.allowance),
          }
        : null
      return { fleet, user }
    },
    staleTime: 10 * 60 * 1000,
    refetchOnWindowFocus: false,
  })

  const updateAllowance = (newAllowance: bigint) => {
    const queryKey = ['fleetInfo', chainId, address, isConnected ? userAddress : undefined]
    const currentData = queryClient.getQueryData(queryKey) as
      | {
          fleet: FleetCommanderInfo
          user: UserFleetInfo | null
        }
      | undefined

    if (currentData?.user) {
      queryClient.setQueryData(queryKey, {
        ...currentData,
        user: {
          ...currentData.user,
          allowance: newAllowance,
        },
      })
    }
  }

  return {
    fleetInfo: query.data?.fleet ?? null,
    userInfo: query.data?.user ?? null,
    loading: query.isLoading,
    error: (query.error as Error) ?? null,
    updateAllowance,
  }
}
