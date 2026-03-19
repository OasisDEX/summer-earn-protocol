'use client'

import { Address } from 'viem'
import { useReadContract } from 'wagmi'

import { wisdomTreeArkAbi } from '../abis/WisdomTreeArk'
import { ChainId } from '../types'

export function useWisdomTreeSharesToAssets({
  arkAddress,
  chainId,
  shares,
  enabled,
}: {
  arkAddress: Address
  chainId: ChainId
  shares: bigint
  enabled: boolean
}) {
  const { data, refetch, isLoading } = useReadContract({
    address: arkAddress,
    abi: wisdomTreeArkAbi,
    functionName: 'sharesToAssets',
    args: [shares],
    chainId: Number(chainId),
    query: {
      enabled,
    },
  })

  return {
    assets: data,
    isLoading,
    refetch,
  }
}
