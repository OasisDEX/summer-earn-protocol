import { cacheLife, cacheTag } from 'next/cache'
import { type Address,isAddress } from 'viem'

import { time } from '@/lib/perf'
import { getPriceClient, type PriceRange } from '@/lib/prices'
import { type ChainId,isSupportedChain } from '@/types/chain'

const VALID_RANGES = new Set<PriceRange>(['7d', '30d', '90d', 'all'])

interface RouteParams {
  params: Promise<{ chainId: string; token: string }>
}

// Cached price-series fetch. The `'use cache'` directive memoises the result
// in Next's data cache, keyed by (chainId, token, range, feed); the
// `cacheTag` calls let us invalidate per-token without flushing the whole
// cache (see `/api/prices/revalidate`).
async function fetchCachedSeries(
  chainId: ChainId,
  token: Address,
  range: PriceRange,
  feed: Address | undefined,
) {
  'use cache'
  // The underlying chainlink-subgraph source snaps `from` and `now` to
  // bucket boundaries (≥ 1h depending on range), so the cached payload is
  // *literally* identical for the entire bucket period. We can afford a
  // much longer revalidate window: 1 hour matches the smallest bucket size
  // and the keeper's hour-aligned `nextTriggerAt`.
  //   - stale 300s   — burst-share the in-memory copy across visitors.
  //   - revalidate 1h — re-pull at the next hour boundary in the background.
  //   - expire 86_400s — drop after a day idle so we never serve > 1d stale.
  cacheLife({ stale: 300, revalidate: 3600, expire: 86_400 })
  cacheTag(
    'price',
    `price:${chainId}`,
    `price:${chainId}:${token.toLowerCase()}`,
    `price:${chainId}:${token.toLowerCase()}:${range}`,
  )
  const client = getPriceClient()
  return client.fetchSeries({ chainId, token, feed, range })
}

export async function GET(request: Request, { params }: RouteParams): Promise<Response> {
  const { chainId: chainIdParam, token: tokenParam } = await params
  if (!isSupportedChain(chainIdParam)) {
    return Response.json({ error: 'unsupported-chain' }, { status: 400 })
  }
  if (!isAddress(tokenParam)) {
    return Response.json({ error: 'invalid-token' }, { status: 400 })
  }
  const chainId: ChainId = chainIdParam
  const token = tokenParam as Address

  const url = new URL(request.url)
  const rangeParam = (url.searchParams.get('range') ?? '30d') as PriceRange
  if (!VALID_RANGES.has(rangeParam)) {
    return Response.json({ error: 'invalid-range' }, { status: 400 })
  }
  const feedParam = url.searchParams.get('feed')
  const feed = feedParam && isAddress(feedParam) ? (feedParam as Address) : undefined

  try {
    const series = await time(
      `route:/api/prices ${token.slice(0, 6)}…/${rangeParam}`,
      () => fetchCachedSeries(chainId, token, rangeParam, feed),
    )
    if (series == null) {
      return Response.json(
        { token, chainId, range: rangeParam, points: [], unknown: true },
        { status: 200 },
      )
    }
    return Response.json(series)
  } catch (err) {
    return Response.json(
      { error: 'fetch-failed', message: (err as Error).message ?? 'unknown' },
      { status: 502 },
    )
  }
}
