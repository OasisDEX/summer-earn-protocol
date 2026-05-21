'use client'

import { keepPreviousData, useQuery } from '@tanstack/react-query'
import type { Address } from 'viem'

import { time } from '@/lib/perf'
import type { PriceRange, PriceSeries } from '@/lib/prices'
import type { ChainId } from '@/types/chain'

interface UseTokenPriceHistoryArgs {
  chainId: ChainId
  token: Address | undefined
  feed?: Address
  range?: PriceRange
  // Pre-resolved series passed down from a server component. Avoids the
  // first-paint round-trip to `/api/prices/...` when present.
  initialSeries?: PriceSeries | null
}

// The route handler returns `{ unknown: true, points: [], ... }` when no
// source recognises the token; surface that as `isUnknown` instead of throwing.
export interface PriceHistoryResult {
  series?: PriceSeries
  isUnknown: boolean
}

export function useTokenPriceHistory({
  chainId,
  token,
  feed,
  range = '30d',
  initialSeries,
}: UseTokenPriceHistoryArgs) {
  return useQuery<PriceHistoryResult>({
    queryKey: ['dca', 'price-history', chainId, token?.toLowerCase(), range, feed?.toLowerCase()],
    enabled: Boolean(token),
    // Matches the route's `revalidate: 3600` (1 hour) — same cadence keeps
    // the UI from re-fetching faster than the server cache rolls over.
    staleTime: 60 * 60_000,
    gcTime: 60 * 60_000,
    initialData: initialSeries ? { series: initialSeries, isUnknown: false } : undefined,
    placeholderData: keepPreviousData,
    queryFn: async (): Promise<PriceHistoryResult> => {
      if (!token) throw new Error('token required')
      const params = new URLSearchParams({ range })
      if (feed) params.set('feed', feed)
      return time(`api:prices ${token.slice(0, 6)}…/${range}`, async () => {
        const res = await fetch(
          `/api/prices/${chainId}/${token.toLowerCase()}?${params.toString()}`,
          { headers: { accept: 'application/json' } },
        )
        if (!res.ok) {
          throw new Error(`price-history request failed: ${res.status}`)
        }
        const body = (await res.json()) as PriceSeries & { unknown?: boolean }
        if (body.unknown) {
          return { isUnknown: true }
        }
        return { series: body, isUnknown: false }
      })
    },
  })
}
