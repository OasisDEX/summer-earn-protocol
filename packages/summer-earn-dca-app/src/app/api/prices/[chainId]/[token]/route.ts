import { cacheLife, cacheTag } from 'next/cache'
import { type Address,isAddress } from 'viem'

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
  // stale 60s — concurrent requests within a minute share the in-memory copy.
  // revalidate 300s — background-refresh aligned with Chainlink heartbeats.
  // expire 86_400s — drop after a day idle so we don't serve stale-by-a-week.
  cacheLife({ stale: 60, revalidate: 300, expire: 86_400 })
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
    const series = await fetchCachedSeries(chainId, token, rangeParam, feed)
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
