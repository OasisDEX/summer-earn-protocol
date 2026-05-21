import { type Address, isAddress } from 'viem'

import { time } from '@/lib/perf'
import { type PriceRange } from '@/lib/prices'
import { fetchCachedSeries } from '@/lib/prices/cached'
import { type ChainId, isSupportedChain } from '@/types/chain'

const VALID_RANGES = new Set<PriceRange>(['7d', '30d', '90d', 'all'])

interface RouteParams {
  params: Promise<{ chainId: string; token: string }>
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
    const series = await time(`route:/api/prices ${token.slice(0, 6)}…/${rangeParam}`, () =>
      fetchCachedSeries(chainId, token, rangeParam, feed),
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
