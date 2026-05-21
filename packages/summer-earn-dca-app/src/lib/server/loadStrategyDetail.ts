import { cacheLife, cacheTag } from 'next/cache'
import { type Address, getAddress } from 'viem'

import 'server-only'

import { aggregatorV3Abi } from '@/abis/AggregatorV3'
import { dcaStrategyManagerAbi } from '@/abis/DCAStrategyManager'
import { erc20Abi } from '@/abis/ERC20'
import { fleetCommanderAbi } from '@/abis/FleetCommander'
import { DCA_STRATEGY_MANAGER_ADDRESSES } from '@/config/addresses'
import { fetchCachedSeries } from '@/lib/prices/cached'
import { type PriceRange, type PriceSeries } from '@/lib/prices/types'
import { getServerPublicClient } from '@/lib/server/rpcClient'
import { gqlFetch } from '@/lib/subgraph/client'
import { STRATEGY_BY_ID } from '@/lib/subgraph/queries'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'
import { type StrategyStateOnchain, StrategyStatus } from '@/types/strategy'

export const DEFAULT_DETAIL_RANGE: PriceRange = '90d'

export interface StrategyMetadata {
  inAsset: { address: Address; symbol: string; decimals: number }
  outAsset: { address: Address; symbol: string; decimals: number }
  sourceVault: { address: Address; symbol: string; decimals: number }
  targetVault: { address: Address; symbol: string; decimals: number }
  inAssetFeed: { address: Address; description: string; decimals: number }
  outAssetFeed: { address: Address; description: string; decimals: number }
}

export interface SourceVaultPreview {
  shares: bigint
  assetsFromShares: bigint
}

export interface StrategyDetailInitial {
  subgraph: SubgraphStrategy | null
  inSeries: PriceSeries | null
  outSeries: PriceSeries | null
  range: PriceRange
  metadata: StrategyMetadata | null
  sourcePreview: SourceVaultPreview | null
  rpcState: StrategyStateOnchain | null
}

async function fetchCachedStrategy(
  chainId: ChainId,
  strategyId: string,
): Promise<SubgraphStrategy | null> {
  'use cache'
  cacheLife({ stale: 30, revalidate: 60, expire: 3600 })
  cacheTag('strategy', `strategy:${chainId}:${strategyId}`)
  const data = await gqlFetch<{ strategy: SubgraphStrategy | null }>(chainId, STRATEGY_BY_ID, {
    id: strategyId,
    executionsFirst: 50,
  })
  return data.strategy
}

async function fetchCachedMetadata(
  chainId: ChainId,
  inAsset: Address,
  outAsset: Address,
  sourceVault: Address,
  targetVault: Address,
  inAssetFeed: Address,
  outAssetFeed: Address,
): Promise<StrategyMetadata> {
  'use cache'
  cacheLife({ stale: 86_400, revalidate: 86_400 * 7, expire: 86_400 * 30 })
  cacheTag(
    'metadata',
    `metadata:${chainId}:${inAsset.toLowerCase()}`,
    `metadata:${chainId}:${outAsset.toLowerCase()}`,
  )
  const client = getServerPublicClient(chainId)
  const calls = [
    { address: inAsset, abi: erc20Abi, functionName: 'symbol' as const },
    { address: inAsset, abi: erc20Abi, functionName: 'decimals' as const },
    { address: outAsset, abi: erc20Abi, functionName: 'symbol' as const },
    { address: outAsset, abi: erc20Abi, functionName: 'decimals' as const },
    { address: sourceVault, abi: erc20Abi, functionName: 'symbol' as const },
    { address: sourceVault, abi: erc20Abi, functionName: 'decimals' as const },
    { address: targetVault, abi: erc20Abi, functionName: 'symbol' as const },
    { address: targetVault, abi: erc20Abi, functionName: 'decimals' as const },
    { address: inAssetFeed, abi: aggregatorV3Abi, functionName: 'description' as const },
    { address: inAssetFeed, abi: aggregatorV3Abi, functionName: 'decimals' as const },
    { address: outAssetFeed, abi: aggregatorV3Abi, functionName: 'description' as const },
    { address: outAssetFeed, abi: aggregatorV3Abi, functionName: 'decimals' as const },
  ]
  const r = await client.multicall({ contracts: calls, allowFailure: false })
  return {
    inAsset: { address: inAsset, symbol: r[0] as string, decimals: r[1] as number },
    outAsset: { address: outAsset, symbol: r[2] as string, decimals: r[3] as number },
    sourceVault: { address: sourceVault, symbol: r[4] as string, decimals: r[5] as number },
    targetVault: { address: targetVault, symbol: r[6] as string, decimals: r[7] as number },
    inAssetFeed: { address: inAssetFeed, description: r[8] as string, decimals: r[9] as number },
    outAssetFeed: {
      address: outAssetFeed,
      description: r[10] as string,
      decimals: r[11] as number,
    },
  }
}

async function fetchCachedSourcePreview(
  chainId: ChainId,
  sourceVault: Address,
  shares: bigint,
): Promise<SourceVaultPreview> {
  'use cache'
  cacheLife({ stale: 30, revalidate: 60, expire: 3600 })
  cacheTag('vault-preview', `vault-preview:${chainId}:${sourceVault.toLowerCase()}`)
  const client = getServerPublicClient(chainId)
  const calls = [
    {
      address: sourceVault,
      abi: fleetCommanderAbi,
      functionName: 'convertToShares' as const,
      args: [0n] as const,
    },
    {
      address: sourceVault,
      abi: fleetCommanderAbi,
      functionName: 'convertToAssets' as const,
      args: [shares] as const,
    },
  ]
  const r = await client.multicall({ contracts: calls, allowFailure: false })
  return {
    shares: r[0] as bigint,
    assetsFromShares: r[1] as bigint,
  }
}

async function fetchCachedStrategyState(
  chainId: ChainId,
  strategyId: bigint,
): Promise<StrategyStateOnchain> {
  'use cache'
  cacheLife({ stale: 15, revalidate: 30, expire: 300 })
  cacheTag('strategy-state', `strategy-state:${chainId}:${strategyId.toString()}`)
  const client = getServerPublicClient(chainId)
  const raw = (await client.readContract({
    address: DCA_STRATEGY_MANAGER_ADDRESSES[chainId],
    abi: dcaStrategyManagerAbi,
    functionName: 'strategyStates',
    args: [strategyId],
  })) as {
    status: number
    tradesExecuted: bigint
    nextTriggerAt: bigint
    lastScheduledAt: bigint
  }
  return {
    status: raw.status as StrategyStatus,
    tradesExecuted: raw.tradesExecuted,
    nextTriggerAt: raw.nextTriggerAt,
    lastScheduledAt: raw.lastScheduledAt,
  }
}

export async function loadStrategyDetail(
  chainId: ChainId,
  strategyId: string,
): Promise<StrategyDetailInitial> {
  const subgraph = await fetchCachedStrategy(chainId, strategyId)
  if (!subgraph) {
    return {
      subgraph: null,
      inSeries: null,
      outSeries: null,
      range: DEFAULT_DETAIL_RANGE,
      metadata: null,
      sourcePreview: null,
      rpcState: null,
    }
  }

  const inAsset = getAddress(subgraph.inAsset) as Address
  const outAsset = getAddress(subgraph.outAsset) as Address
  const inAssetFeed = getAddress(subgraph.inAssetFeed) as Address
  const outAssetFeed = getAddress(subgraph.outAssetFeed) as Address
  const sourceVault = getAddress(subgraph.sourceVault) as Address
  const targetVault = getAddress(subgraph.targetVault) as Address
  const tradeAmount = BigInt(subgraph.tradeAmount)
  const idBig = BigInt(subgraph.strategyId)

  const [inSeries, outSeries, metadata, sourcePreview, rpcState] = await Promise.all([
    fetchCachedSeries(chainId, inAsset, DEFAULT_DETAIL_RANGE, inAssetFeed),
    fetchCachedSeries(chainId, outAsset, DEFAULT_DETAIL_RANGE, outAssetFeed),
    fetchCachedMetadata(
      chainId,
      inAsset,
      outAsset,
      sourceVault,
      targetVault,
      inAssetFeed,
      outAssetFeed,
    ).catch(() => null),
    fetchCachedSourcePreview(chainId, sourceVault, tradeAmount).catch(() => null),
    fetchCachedStrategyState(chainId, idBig).catch(() => null),
  ])

  return {
    subgraph,
    inSeries,
    outSeries,
    range: DEFAULT_DETAIL_RANGE,
    metadata,
    sourcePreview,
    rpcState,
  }
}
