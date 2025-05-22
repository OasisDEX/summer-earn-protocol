'use client'

import { useEffect, useState } from 'react'
import { createPublicClient, http } from 'viem'
import { useAccount } from 'wagmi'
import { erc20Abi } from '../abis/ERC20'
import { fleetCommanderAbi } from '../abis/FleetCommander'
import { CHAIN_RPC_URLS } from '../config/chains'
import { FleetCommanderInfo, UserFleetInfo } from '../types'

interface UseFleetInfoProps {
  address: `0x${string}`
  chainId: string
}

export function useFleetInfo({ address, chainId }: UseFleetInfoProps) {
  const [fleetInfo, setFleetInfo] = useState<FleetCommanderInfo | null>(null)
  const [userInfo, setUserInfo] = useState<UserFleetInfo | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const { address: userAddress, isConnected } = useAccount()

  useEffect(() => {
    const fetchFleetInfo = async () => {
      try {
        const client = createPublicClient({
          transport: http(CHAIN_RPC_URLS[chainId as keyof typeof CHAIN_RPC_URLS]),
        })

        const [name, symbol, assetAddress, totalAssets, withdrawableTotalAssets] =
          await Promise.all([
            client.readContract({
              address,
              abi: fleetCommanderAbi,
              functionName: 'name',
            }),
            client.readContract({
              address,
              abi: fleetCommanderAbi,
              functionName: 'symbol',
            }),
            client.readContract({
              address,
              abi: fleetCommanderAbi,
              functionName: 'asset',
            }),
            client.readContract({
              address,
              abi: fleetCommanderAbi,
              functionName: 'totalAssets',
            }),
            client.readContract({
              address,
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

        // Get deposit cap
        const depositCap = BigInt(0) // This is a placeholder, we need to implement this

        setFleetInfo({
          address,
          name,
          symbol,
          asset: assetAddress,
          totalAssets,
          withdrawableTotalAssets,
          depositCap,
          assetDecimals,
          assetSymbol,
        })

        // If user is connected, fetch user-specific info
        if (isConnected && userAddress) {
          const [balance, underlyingBalance, allowance] = await Promise.all([
            client.readContract({
              address,
              abi: fleetCommanderAbi,
              functionName: 'balanceOf',
              args: [userAddress],
            }),
            client.readContract({
              address: assetAddress,
              abi: erc20Abi,
              functionName: 'balanceOf',
              args: [userAddress],
            }),
            client.readContract({
              address: assetAddress,
              abi: erc20Abi,
              functionName: 'allowance',
              args: [userAddress, address],
            }),
          ])

          setUserInfo({
            balance,
            underlyingBalance,
            allowance,
          })
        }

        setLoading(false)
      } catch (err) {
        console.error('Error fetching fleet info:', err)
        setError(err instanceof Error ? err : new Error(String(err)))
        setLoading(false)
      }
    }

    fetchFleetInfo()
  }, [address, chainId, isConnected, userAddress])

  return {
    fleetInfo,
    userInfo,
    loading,
    error,
  }
}
