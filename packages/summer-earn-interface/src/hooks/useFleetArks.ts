'use client'

import { useEffect, useState } from 'react'
import { Abi, createPublicClient, http } from 'viem'
import { arkAbi } from '../abis/Ark'
import { fleetCommanderAbi } from '../abis/FleetCommander'
import { CHAIN_RPC_URLS, VIEM_CHAIN_ENTITIES } from '../config/chains'
import { ArkInfo } from '../types'

interface UseFleetArksProps {
  fleetAddress: `0x${string}`
  chainId: string
}

type MulticallContract = {
  address: `0x${string}`
  abi: Abi
  functionName: string
}

export function useFleetArks({ fleetAddress, chainId }: UseFleetArksProps) {
  const [arks, setArks] = useState<ArkInfo[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  useEffect(() => {
    const fetchArks = async () => {
      try {
        setLoading(true)

        const client = createPublicClient({
          chain: VIEM_CHAIN_ENTITIES[chainId as keyof typeof VIEM_CHAIN_ENTITIES],
          transport: http(CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]),
        })

        // Get all active arks for the fleet
        const activeArks = await client.readContract({
          address: fleetAddress,
          abi: fleetCommanderAbi,
          functionName: 'getActiveArks',
        })

        if (activeArks.length === 0) {
          setArks([])
          setLoading(false)
          return
        }

        // Prepare multicall data for all arks
        const multicallData: MulticallContract[] = []

        // For each ark, we want totalAssets and withdrawableTotalAssets
        for (const arkAddress of activeArks) {
          multicallData.push({
            address: arkAddress,
            abi: arkAbi as Abi,
            functionName: 'totalAssets',
          })

          multicallData.push({
            address: arkAddress,
            abi: arkAbi as Abi,
            functionName: 'withdrawableTotalAssets',
          })
          multicallData.push({
            address: arkAddress,
            abi: arkAbi as Abi,
            functionName: 'name',
          })
        }

        // Execute multicall
        // @ts-expect-error - Type instantiation is excessively deep
        const results = await client.multicall({
          contracts: multicallData,
        })

        // Process results
        const arksData: ArkInfo[] = []
        for (let i = 0; i < activeArks.length; i++) {
          const totalAssetsResult = results[i * 3]
          const withdrawableAssetsResult = results[i * 3 + 1]
          const nameResult = results[i * 3 + 2]
          if (
            totalAssetsResult.status === 'success' &&
            withdrawableAssetsResult.status === 'success' &&
            nameResult.status === 'success'
          ) {
            arksData.push({
              address: activeArks[i],
              totalAssets: totalAssetsResult.result as bigint,
              withdrawableTotalAssets: withdrawableAssetsResult.result as bigint,
              name: nameResult.result as string,
            })
          } else {
            console.error('Error fetching ark data:', activeArks[i])
          }
        }

        setArks(arksData)
        setLoading(false)
      } catch (err) {
        console.error('Error fetching ark data:', err)
        setError(err instanceof Error ? err : new Error(String(err)))
        setLoading(false)
      }
    }

    if (fleetAddress) {
      fetchArks()
    }
  }, [fleetAddress, chainId])

  return {
    arks,
    loading,
    error,
  }
}
