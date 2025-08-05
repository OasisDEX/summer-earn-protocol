'use client'

import { useEffect, useState } from 'react'
import { createPublicClient, http } from 'viem'
import { useReadContract } from 'wagmi'
import { erc20Abi } from '../abis/ERC20'
import { fleetCommanderAbi } from '../abis/FleetCommander'
import { harborCommandAbi } from '../abis/HarborCommand'
import { CHAIN_RPC_URLS, VIEM_CHAIN_ENTITIES } from '../config/chains'
import { FleetCommanderInfo } from '../types'

interface UseActiveFleetsProps {
  chainId: string
  harborCommandAddress: string
}

export function useActiveFleets({ chainId, harborCommandAddress }: UseActiveFleetsProps) {
  const [fleets, setFleets] = useState<FleetCommanderInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const {
    data: activeFleets,
    isError,
    isLoading,
    error: contractError,
  } = useReadContract({
    address: harborCommandAddress as `0x${string}`,
    abi: harborCommandAbi,
    functionName: 'getActiveFleetCommanders',
    chainId: VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES].id,
  })

  useEffect(() => {
    const fetchFleetInfo = async () => {
      if (isError) {
        setError(contractError || new Error('Failed to fetch active fleets'))
        setLoading(false)
        return
      }

      if (isLoading || !activeFleets) {
        return
      }

      try {
        const client = createPublicClient({
          transport: http(CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]),
        })

        const fleetInfoPromises = (activeFleets as `0x${string}`[]).map(async (fleetAddress) => {
          const [name, symbol, assetAddress, totalAssets, withdrawableTotalAssets] =
            await Promise.all([
              client.readContract({
                address: fleetAddress,
                abi: fleetCommanderAbi,
                functionName: 'name',
              }),
              client.readContract({
                address: fleetAddress,
                abi: fleetCommanderAbi,
                functionName: 'symbol',
              }),
              client.readContract({
                address: fleetAddress,
                abi: fleetCommanderAbi,
                functionName: 'asset',
              }),
              client.readContract({
                address: fleetAddress,
                abi: fleetCommanderAbi,
                functionName: 'totalAssets',
              }),
              client.readContract({
                address: fleetAddress,
                abi: fleetCommanderAbi,
                functionName: 'withdrawableTotalAssets',
              }),
            ])

          const [assetDecimals, assetSymbol] = await Promise.all([
            client.readContract({
              address: assetAddress,
              abi: erc20Abi,
              functionName: 'decimals',
            }),
            client.readContract({
              address: assetAddress,
              abi: erc20Abi,
              functionName: 'symbol',
            }),
          ])

          return {
            address: fleetAddress,
            name,
            symbol,
            asset: assetAddress,
            totalAssets,
            withdrawableTotalAssets,
            depositCap: BigInt(0), // Placeholder
            assetDecimals,
            assetSymbol,
            fleetDecimals: assetDecimals,
          }
        })

        const fleetInfo = await Promise.all(fleetInfoPromises)
        setFleets(fleetInfo)
        setLoading(false)
      } catch (err) {
        console.error('Error fetching fleet info:', err)
        setError(err instanceof Error ? err : new Error(String(err)))
        setLoading(false)
      }
    }

    fetchFleetInfo()
  }, [activeFleets, isError, isLoading, contractError, chainId])

  return {
    fleets,
    loading,
    error,
  }
}
