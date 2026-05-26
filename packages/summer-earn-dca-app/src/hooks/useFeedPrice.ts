'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { usePublicClient } from 'wagmi'

import { aggregatorV3Abi } from '@/abis/AggregatorV3'
import { time } from '@/lib/perf'
import type { ChainId } from '@/types/chain'

export interface FeedPrice {
  feed: Address
  answer: bigint
  decimals: number
  updatedAt: bigint
}

export function useFeedPrice(chainId: ChainId, feed: Address | undefined) {
  const client = usePublicClient({ chainId: Number(chainId) })

  return useQuery({
    queryKey: ['dca', 'feed-price', chainId, feed?.toLowerCase()] as const,
    enabled: Boolean(feed && client),
    refetchInterval: 60_000,
    staleTime: 60_000,
    queryFn: async (): Promise<FeedPrice> => {
      if (!client || !feed) throw new Error('not ready')
      return time(`rpc:feed ${feed.slice(0, 6)}…`, async () => {
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
      })
    },
  })
}
