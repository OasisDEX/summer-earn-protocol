'use client'

import { useMemo } from 'react'
import { type Address, getAddress } from 'viem'

import { useHybridStrategy } from '@/hooks/useHybridStrategy'
import { useStrategyMetadata } from '@/hooks/useTokenMetadata'
import { useTokenPriceHistory } from '@/hooks/useTokenPriceHistory'
import type { PriceBasis, PricePoint, PriceRange, PriceSeries } from '@/lib/prices'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

// Optional pre-resolved data from a server component loader. Lets the
// hooks seed TanStack with initialData so first paint doesn't wait on any
// network round-trip.
export interface StrategyChartInitialData {
  subgraph?: SubgraphStrategy | null
  inSeries?: PriceSeries | null
  outSeries?: PriceSeries | null
  /** The range the initial series cover — `useTokenPriceHistory` keys on
   *  range so we only apply `initialSeries` when the consumer asks for the
   *  same range. */
  range?: PriceRange
}

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

// Merge two sorted gap arrays into a single union — used when both series
// contribute gaps to the resulting ratio series.
function mergeGaps(
  a: Array<[number, number]>,
  b: Array<[number, number]>,
): Array<[number, number]> {
  const merged: Array<[number, number]> = [...a, ...b].sort((x, y) => x[0] - y[0])
  const out: Array<[number, number]> = []
  for (const [s, e] of merged) {
    const tail = out[out.length - 1]
    if (tail && s <= tail[1]) {
      tail[1] = Math.max(tail[1], e)
    } else {
      out.push([s, e])
    }
  }
  return out
}

// Composes:
//   - hybrid strategy (subgraph row + RPC state)
//   - outAsset price-history (USD per outAsset over time)
//   - inAsset price-history (USD per inAsset over time)
//   - strategy metadata (decimals / symbols, via the existing hook)
//
// The chart line is the inAsset-per-outAsset RATIO over time (i.e.
// outPriceUSD / inPriceUSD at each timestamp), so it lives in the same
// numeric space as the contract's 1e18-scaled `maxPrice`/`minPrice`
// guardrails. Execution dots use the realised ratio amountIn/amountOut from
// each completed swap (in real units).
export function useStrategyChartData(
  chainId: ChainId,
  strategyId: string | undefined,
  range: PriceRange = '90d',
  initial?: StrategyChartInitialData,
) {
  const hybrid = useHybridStrategy(chainId, strategyId, initial?.subgraph)
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

  // Only apply the server-pre-resolved series when the consumer hasn't
  // switched to a different range yet — otherwise TanStack would re-seed
  // the new range's queryKey with stale points from the initial range.
  const seedSeries = initial?.range === range ? initial : undefined

  const outQuery = useTokenPriceHistory({
    chainId,
    token: sg ? (getAddress(sg.outAsset) as Address) : undefined,
    feed: sg ? (getAddress(sg.outAssetFeed) as Address) : undefined,
    range,
    initialSeries: seedSeries?.outSeries,
  })
  const inQuery = useTokenPriceHistory({
    chainId,
    token: sg ? (getAddress(sg.inAsset) as Address) : undefined,
    feed: sg ? (getAddress(sg.inAssetFeed) as Address) : undefined,
    range,
    initialSeries: seedSeries?.inSeries,
  })

  const data = useMemo<StrategyChartData | undefined>(() => {
    if (!sg || !metadata.data) return undefined
    const outSeries = outQuery.data?.series
    const inSeries = inQuery.data?.series

    const inAssetDecimals = metadata.data.inAsset.decimals
    const outAssetDecimals = metadata.data.outAsset.decimals

    // Guardrails are stored as the 1e18-scaled out/in execution-price ratio
    // (see DCAStrategyManager._executionPrice). Decode to a plain float for
    // the chart's y-axis.
    const ceiling = sg.maxPrice && sg.maxPrice !== '0' ? Number(sg.maxPrice) / 1e18 : undefined
    const floor = sg.minPrice && sg.minPrice !== '0' ? Number(sg.minPrice) / 1e18 : undefined

    // Build a pointwise ratio series outPrice/inPrice. We anchor on the
    // outAsset series timestamps (typically the volatile asset, denser cadence)
    // and look up the nearest inAsset point. Drop any point where the
    // inAsset is unknown so we don't divide by zero.
    const prices: PricePoint[] = []
    if (outSeries && inSeries && outSeries.points.length > 0 && inSeries.points.length > 0) {
      for (const op of outSeries.points) {
        const ip = findNearest(inSeries.points, op.t)
        if (!ip || ip === 0) continue
        prices.push({ t: op.t, p: op.p / ip })
      }
    }

    const gaps = mergeGaps(outSeries?.gaps ?? [], inSeries?.gaps ?? [])

    const executions: StrategyChartExecution[] = (sg.executions ?? []).map((e) => {
      const tMs = Number(e.executionTimestamp) * 1000
      const amountInF = Number(e.amountIn) / Math.pow(10, inAssetDecimals)
      const amountOutF = Number(e.amountOut) / Math.pow(10, outAssetDecimals)
      // Realised execution ratio in the same units as the guardrails.
      const p = amountOutF > 0 ? amountInF / amountOutF : 0
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
    } else if (inSeries && inSeries.basis !== basis) {
      basis = 'mixed'
    }

    // The ratio can't begin before BOTH feeds had data.
    const dataStartsAt =
      outSeries?.dataStartsAt !== undefined && inSeries?.dataStartsAt !== undefined
        ? Math.max(outSeries.dataStartsAt, inSeries.dataStartsAt)
        : outSeries?.dataStartsAt ?? inSeries?.dataStartsAt

    return {
      prices,
      gaps,
      executions,
      ceiling,
      floor,
      basis,
      dataStartsAt,
      outAssetSymbol: metadata.data.outAsset.symbol,
      inAssetSymbol: metadata.data.inAsset.symbol,
    }
  }, [sg, metadata.data, outQuery.data?.series, inQuery.data?.series])

  // "Loading" means: we don't yet know what the chart should show. Plain
  // `outQuery.isLoading || inQuery.isLoading` lies because the queries flip
  // from disabled (sg undefined) to pending across two render frames — for a
  // single frame all four flags are false and the parent flashes the empty
  // state before the fetch actually starts. Anchor on data presence instead
  // (`!outQuery.data || !inQuery.data`); on range changes
  // `placeholderData: keepPreviousData` keeps `data` defined so the chart
  // transitions smoothly without re-flashing the skeleton.
  return {
    data,
    isLoading: hybrid.isLoading || metadata.isLoading || !outQuery.data || !inQuery.data,
    isError: hybrid.isError || outQuery.isError || inQuery.isError,
    isUnknown: (outQuery.data?.isUnknown ?? false) && !outQuery.data?.series,
    refetchSubgraph: hybrid.refetchSubgraph,
  }
}
