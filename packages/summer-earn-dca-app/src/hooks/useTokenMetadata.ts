'use client'

import { useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'
import { usePublicClient } from 'wagmi'

import { aggregatorV3Abi } from '@/abis/AggregatorV3'
import { erc20Abi } from '@/abis/ERC20'
import { time } from '@/lib/perf'
import type { ChainId } from '@/types/chain'

export interface TokenMetadata {
  address: Address
  symbol: string
  decimals: number
}

export interface FeedMetadata {
  address: Address
  description: string
  decimals: number
}

export interface StrategyMetadata {
  inAsset: TokenMetadata
  outAsset: TokenMetadata
  sourceVault: TokenMetadata
  targetVault: TokenMetadata
  inAssetFeed: FeedMetadata
  outAssetFeed: FeedMetadata
}

interface UseStrategyMetadataInput {
  chainId: ChainId
  inAsset?: Address
  outAsset?: Address
  sourceVault?: Address
  targetVault?: Address
  inAssetFeed?: Address
  outAssetFeed?: Address
  // Pre-resolved metadata from a server component loader. Lets the client
  // skip the 12-read multicall on first render.
  initialData?: StrategyMetadata | null
}

// Batched ERC20.symbol/decimals and AggregatorV3.description/decimals reads
// for one strategy. Cached forever (per address) — metadata is immutable.
export function useStrategyMetadata(input: UseStrategyMetadataInput) {
  const client = usePublicClient({ chainId: Number(input.chainId) })
  const allAddresses = [
    input.inAsset,
    input.outAsset,
    input.sourceVault,
    input.targetVault,
    input.inAssetFeed,
    input.outAssetFeed,
  ]
  const ready = allAddresses.every((a): a is Address => Boolean(a)) && Boolean(client)

  return useQuery({
    queryKey: ['dca', 'metadata', input.chainId, ...allAddresses.map((a) => a?.toLowerCase())],
    enabled: ready,
    staleTime: Number.POSITIVE_INFINITY,
    initialData: input.initialData ?? undefined,
    queryFn: async (): Promise<StrategyMetadata> => {
      if (!client) throw new Error('Public client unavailable')
      return time('rpc:strategy-metadata', async () => {
        const calls = [
          // 0-1: inAsset symbol+decimals
          { address: input.inAsset!, abi: erc20Abi, functionName: 'symbol' as const },
          { address: input.inAsset!, abi: erc20Abi, functionName: 'decimals' as const },
          // 2-3: outAsset
          { address: input.outAsset!, abi: erc20Abi, functionName: 'symbol' as const },
          { address: input.outAsset!, abi: erc20Abi, functionName: 'decimals' as const },
          // 4-5: sourceVault
          { address: input.sourceVault!, abi: erc20Abi, functionName: 'symbol' as const },
          { address: input.sourceVault!, abi: erc20Abi, functionName: 'decimals' as const },
          // 6-7: targetVault
          { address: input.targetVault!, abi: erc20Abi, functionName: 'symbol' as const },
          { address: input.targetVault!, abi: erc20Abi, functionName: 'decimals' as const },
          // 8-9: inAssetFeed description+decimals
          {
            address: input.inAssetFeed!,
            abi: aggregatorV3Abi,
            functionName: 'description' as const,
          },
          {
            address: input.inAssetFeed!,
            abi: aggregatorV3Abi,
            functionName: 'decimals' as const,
          },
          // 10-11: outAssetFeed
          {
            address: input.outAssetFeed!,
            abi: aggregatorV3Abi,
            functionName: 'description' as const,
          },
          {
            address: input.outAssetFeed!,
            abi: aggregatorV3Abi,
            functionName: 'decimals' as const,
          },
        ]
        const result = await client.multicall({ contracts: calls, allowFailure: false })
        return {
          inAsset: {
            address: input.inAsset!,
            symbol: result[0] as string,
            decimals: result[1] as number,
          },
          outAsset: {
            address: input.outAsset!,
            symbol: result[2] as string,
            decimals: result[3] as number,
          },
          sourceVault: {
            address: input.sourceVault!,
            symbol: result[4] as string,
            decimals: result[5] as number,
          },
          targetVault: {
            address: input.targetVault!,
            symbol: result[6] as string,
            decimals: result[7] as number,
          },
          inAssetFeed: {
            address: input.inAssetFeed!,
            description: result[8] as string,
            decimals: result[9] as number,
          },
          outAssetFeed: {
            address: input.outAssetFeed!,
            description: result[10] as string,
            decimals: result[11] as number,
          },
        }
      })
    },
  })
}

// Lightweight single-token variant used by the create form when the user
// types a custom address.
export function useTokenMetadata(chainId: ChainId, token?: Address) {
  const client = usePublicClient({ chainId: Number(chainId) })
  return useQuery({
    queryKey: ['dca', 'token-meta', chainId, token?.toLowerCase()],
    enabled: Boolean(token) && Boolean(client),
    staleTime: Number.POSITIVE_INFINITY,
    queryFn: async (): Promise<TokenMetadata> => {
      if (!client || !token) throw new Error('not ready')
      const [symbol, decimals] = await client.multicall({
        contracts: [
          { address: token, abi: erc20Abi, functionName: 'symbol' },
          { address: token, abi: erc20Abi, functionName: 'decimals' },
        ],
        allowFailure: false,
      })
      return { address: token, symbol: symbol as string, decimals: decimals as number }
    },
  })
}
