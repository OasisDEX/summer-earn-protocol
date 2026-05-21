import { cacheLife, cacheTag } from 'next/cache'
import { type Address } from 'viem'

import 'server-only'

import { getPriceClient } from '@/lib/prices'
import { type PriceRange } from '@/lib/prices/types'
import { type ChainId } from '@/types/chain'

// Shared `'use cache'` entry for price-history fetches. Used by both the
// public `/api/prices/[chainId]/[token]` route handler AND the strategy
// detail page's server-side loader, so a cache fill from either consumer
// serves the other. Same cacheTag scheme lets `/api/prices/revalidate`
// (POST) drop both call paths in a single `updateTag()`.
//
// The underlying chainlink-subgraph source snaps `from`/`now` to bucket
// boundaries, so the response is byte-identical inside one bucket period.
// We can afford a 1h revalidate window aligned with the smallest bucket.
export async function fetchCachedSeries(
  chainId: ChainId,
  token: Address,
  range: PriceRange,
  feed: Address | undefined,
) {
  'use cache'
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
