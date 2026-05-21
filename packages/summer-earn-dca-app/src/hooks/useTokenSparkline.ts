'use client'

import { useMemo } from 'react'
import type { Address } from 'viem'

import type { ChainId } from '@/types/chain'

import { useTokenPriceHistory } from './useTokenPriceHistory'

const POINTS = 20

// Tiny shim over `useTokenPriceHistory` — reuses the 30d cached series and
// downsamples to the last `POINTS` daily points, the shape the KPI tile
// Sparkline component takes.
export function useTokenSparkline(chainId: ChainId, token: Address | undefined) {
  const query = useTokenPriceHistory({ chainId, token, range: '30d' })

  const points = useMemo<number[]>(() => {
    if (!query.data?.series) return []
    return query.data.series.points.slice(-POINTS).map((p) => p.p)
  }, [query.data?.series])

  return {
    points,
    isLoading: query.isLoading,
    isError: query.isError,
    isUnknown: query.data?.isUnknown ?? false,
  }
}
