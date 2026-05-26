import { cacheLife, cacheTag } from 'next/cache'
import { type Address } from 'viem'

import 'server-only'

import { getPriceClient } from '@/lib/prices'
import { type PriceRange } from '@/lib/prices/types'
import { type ChainId } from '@/types/chain'

// Shared cache entry for price-history fetches: same payload served whether
// the consumer is the `/api/prices/...` route or the strategy detail page's
// server-side loader. `cacheTag` matches what `/api/prices/revalidate`
// (POST) calls via `updateTag()`.
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
