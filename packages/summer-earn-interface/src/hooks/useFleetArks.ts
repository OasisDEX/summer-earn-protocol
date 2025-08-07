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

        // Get all active arks and buffer ark for the fleet
        const [activeArks, bufferArkAddress] = await Promise.all([
          client.readContract({
            address: fleetAddress,
            abi: fleetCommanderAbi,
            functionName: 'getActiveArks',
          }),
          client.readContract({
            address: fleetAddress,
            abi: fleetCommanderAbi,
            functionName: 'bufferArk',
          })
        ])

        // Combine active arks with buffer ark
        const allArks = [...activeArks, bufferArkAddress]
        
        if (allArks.length === 0) {
          setArks([])
          setLoading(false)
          return
        }

        // Prepare multicall data for all arks
        const multicallData: MulticallContract[] = []

        // For each ark, we want totalAssets and withdrawableTotalAssets
        for (const arkAddress of allArks) {
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
        for (let i = 0; i < allArks.length; i++) {
          const totalAssetsResult = results[i * 3]
          const withdrawableAssetsResult = results[i * 3 + 1]
          const nameResult = results[i * 3 + 2]
          if (
            totalAssetsResult.status === 'success' &&
            withdrawableAssetsResult.status === 'success' &&
            nameResult.status === 'success'
          ) {
            // Check if this is the buffer ark (last in the allArks array)
            const isBufferArk = i === allArks.length - 1
            arksData.push({
              address: allArks[i],
              totalAssets: totalAssetsResult.result as bigint,
              withdrawableTotalAssets: withdrawableAssetsResult.result as bigint,
              name: nameResult.result as string,
              isBufferArk,
            })
          } else {
            console.error('Error fetching ark data:', allArks[i])
          }
        }

        // Sort arks to show buffer ark first
        const sortedArks = arksData.sort((a, b) => {
          if (a.isBufferArk && !b.isBufferArk) return -1
          if (!a.isBufferArk && b.isBufferArk) return 1
          return 0
        })
        
        setArks(sortedArks)
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
