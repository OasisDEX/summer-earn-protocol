'use client'

import { useMemo } from 'react'
import { type Address, getAddress } from 'viem'

import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import { useTokenPriceHistory } from '@/hooks/useTokenPriceHistory'
import type { PriceBasis, PricePoint, PriceRange } from '@/lib/prices'
import type { ChainId } from '@/types/chain'

export interface StrategyChartExecution {
  t: number
  p: number
  amountIn: bigint
  amountOut: bigint
  txHash: `0x${string}`
  skipped: boolean
}

export interface StrategyChartData {
  prices: PricePoint[]
  gaps: Array<[number, number]>
  executions: StrategyChartExecution[]
  ceiling?: number
  floor?: number
  basis: PriceBasis
  dataStartsAt?: number
  outAssetSymbol?: string
  inAssetSymbol?: string
}

function findNearest(points: PricePoint[], tMs: number): number | undefined {
  if (points.length === 0) return undefined
  let lo = 0
  let hi = points.length - 1
  while (lo < hi) {
    const mid = (lo + hi) >>> 1
    if (points[mid].t < tMs) lo = mid + 1
    else hi = mid
  }
  // Lookup nearest by index +/- 1.
  const candidates: number[] = []
  if (lo > 0) candidates.push(lo - 1)
  candidates.push(lo)
  if (lo < points.length - 1) candidates.push(lo + 1)
  let best = candidates[0]
  for (const idx of candidates) {
    if (Math.abs(points[idx].t - tMs) < Math.abs(points[best].t - tMs)) {
      best = idx
    }
  }
  return points[best].p
}

// Composes:
//   - hybrid strategy (subgraph row + RPC state)
//   - outAsset price-history (the chart line)
//   - inAsset price-history (used to convert execution amounts to USD when
//     the inAsset isn't a stable)
//   - strategy metadata (decimals / symbols, via the existing hook)
// Returns the merged shape the LineChart consumes.
export function useStrategyChartData(
  chainId: ChainId,
  strategyId: string | undefined,
  range: PriceRange = '90d',
) {
  const hybrid = useHybridStrategy(chainId, strategyId)
  const sg = hybrid.data?.subgraph

  const metadata = useStrategyMetadata({
    chainId,
    inAsset: sg ? (getAddress(sg.inAsset) as Address) : undefined,
    outAsset: sg ? (getAddress(sg.outAsset) as Address) : undefined,
    sourceVault: sg ? (getAddress(sg.sourceVault) as Address) : undefined,
    targetVault: sg ? (getAddress(sg.targetVault) as Address) : undefined,
    inAssetFeed: sg ? (getAddress(sg.inAssetFeed) as Address) : undefined,
    outAssetFeed: sg ? (getAddress(sg.outAssetFeed) as Address) : undefined,
  })

  const outQuery = useTokenPriceHistory({
    chainId,
    token: sg ? (getAddress(sg.outAsset) as Address) : undefined,
    feed: sg ? (getAddress(sg.outAssetFeed) as Address) : undefined,
    range,
  })
  const inQuery = useTokenPriceHistory({
    chainId,
    token: sg ? (getAddress(sg.inAsset) as Address) : undefined,
    feed: sg ? (getAddress(sg.inAssetFeed) as Address) : undefined,
    range,
  })

  const data = useMemo<StrategyChartData | undefined>(() => {
    if (!sg || !metadata.data) return undefined
    const outSeries = outQuery.data?.series
    const inSeries = inQuery.data?.series

    const prices: PricePoint[] = outSeries?.points ?? []
    const gaps: Array<[number, number]> = outSeries?.gaps ?? []

    const outFeedDecimals = metadata.data.outAssetFeed.decimals
    const inAssetDecimals = metadata.data.inAsset.decimals
    const outAssetDecimals = metadata.data.outAsset.decimals

    const denomOut = Math.pow(10, outFeedDecimals)
    const ceiling =
      sg.maxPrice && sg.maxPrice !== '0' ? Number(sg.maxPrice) / denomOut : undefined
    const floor =
      sg.minPrice && sg.minPrice !== '0' ? Number(sg.minPrice) / denomOut : undefined

    const inPriceAt = (tMs: number): number => {
      if (!inSeries || inSeries.points.length === 0) return 1
      return findNearest(inSeries.points, tMs) ?? 1
    }

    const executions: StrategyChartExecution[] = (sg.executions ?? []).map((e) => {
      const tMs = Number(e.executionTimestamp) * 1000
      const amountInF = Number(e.amountIn) / Math.pow(10, inAssetDecimals)
      const amountOutF = Number(e.amountOut) / Math.pow(10, outAssetDecimals)
      const inUsd = inPriceAt(tMs)
      // Execution price = USD spent / outAsset received.
      const p = amountOutF > 0 ? (amountInF * inUsd) / amountOutF : 0
      return {
        t: tMs,
        p,
        amountIn: BigInt(e.amountIn),
        amountOut: BigInt(e.amountOut),
        txHash: e.txHash,
        skipped: false,
      }
    })

    let basis: PriceBasis = outSeries?.basis ?? 'chainlink-feed'
    if (outSeries && inSeries && outSeries.basis !== inSeries.basis) {
      basis = 'mixed'
    }

    return {
      prices,
      gaps,
      executions,
      ceiling,
      floor,
      basis,
      dataStartsAt: outSeries?.dataStartsAt,
      outAssetSymbol: metadata.data.outAsset.symbol,
      inAssetSymbol: metadata.data.inAsset.symbol,
    }
  }, [sg, metadata.data, outQuery.data?.series, inQuery.data?.series])

  return {
    data,
    isLoading:
      hybrid.isLoading ||
      metadata.isLoading ||
      outQuery.isLoading ||
      inQuery.isLoading,
    isError: hybrid.isError || outQuery.isError || inQuery.isError,
    isUnknown:
      (outQuery.data?.isUnknown ?? false) && !(outQuery.data?.series),
    refetchSubgraph: hybrid.refetchSubgraph,
  }
}
