import { NextResponse } from 'next/server'

import { CHAIN_SUBGRAPH_URLS } from '@/config/chains'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  const url = new URL(request.url)
  const chainId = url.searchParams.get('chainId') || '1'
  const productId = url.searchParams.get('productId')
  const from = url.searchParams.get('from') || '0'
  if (!productId) return NextResponse.json({ error: 'productId required' }, { status: 400 })
  const key = `daily:${chainId}:${productId}:${from}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const endpoint = CHAIN_SUBGRAPH_URLS[chainId as keyof typeof CHAIN_SUBGRAPH_URLS]
  if (!endpoint) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        query($productId: String!, $fromTimestamp: BigInt!) {
          dailyInterestRates(
            where: { productId: $productId, date_gte: $fromTimestamp }
            orderBy: date
            orderDirection: asc
            first: 1000
          ) {
            id date sumRates updateCount averageRate protocol token productId
            product { id name protocol token { id symbol decimals } }
            interestRates { id type rate timestamp }
          }
        }
      `,
      variables: { productId, fromTimestamp: from },
    }),
    cache: 'no-store',
  })
  const data = await response.json()
  const payload = data.data?.dailyInterestRates ?? []
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
