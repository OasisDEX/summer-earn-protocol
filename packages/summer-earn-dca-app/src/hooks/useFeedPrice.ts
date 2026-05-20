'use client'

import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import type { Address } from 'viem'
import { useBlockNumber, usePublicClient } from 'wagmi'

import { aggregatorV3Abi } from '@/abis/AggregatorV3'
import type { ChainId } from '@/types/chain'

export interface FeedPrice {
  feed: Address
  answer: bigint
  decimals: number
  updatedAt: bigint
}

// Reads latestRoundData + decimals + description from a Chainlink feed and
// repolls on every new block. Repol blocks are cheap on Base and this lets us
// show the freshest price without manual refetch.
export function useFeedPrice(chainId: ChainId, feed: Address | undefined) {
  const client = usePublicClient({ chainId: Number(chainId) })
  const queryClient = useQueryClient()

  const queryKey = ['dca', 'feed-price', chainId, feed?.toLowerCase()] as const

  const query = useQuery({
    queryKey,
    enabled: Boolean(feed && client),
    queryFn: async (): Promise<FeedPrice> => {
      if (!client || !feed) throw new Error('not ready')
      const [latest, decimals] = await client.multicall({
        contracts: [
          { address: feed, abi: aggregatorV3Abi, functionName: 'latestRoundData' },
          { address: feed, abi: aggregatorV3Abi, functionName: 'decimals' },
        ],
        allowFailure: false,
      })
      const [, answer, , updatedAt] = latest as readonly [bigint, bigint, bigint, bigint, bigint]
      return {
        feed,
        answer,
        decimals: decimals as number,
        updatedAt,
      }
    },
  })

  const { data: blockNumber } = useBlockNumber({ chainId: Number(chainId), watch: Boolean(feed) })

  useEffect(() => {
    if (!feed || !blockNumber) return
    queryClient.invalidateQueries({ queryKey })
    // queryKey is stable in identity per (chainId, feed); safe to depend on.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [blockNumber, feed, chainId])

  return query
}
