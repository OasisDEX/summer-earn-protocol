import { NextResponse } from 'next/server'

import { CHAIN_SUBGRAPH_URLS } from '@/config/chains'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  const url = new URL(request.url)
  const chainId = url.searchParams.get('chainId') || '1'
  const key = `products:${chainId}`
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
        query { products { id name protocol token { id address symbol decimals precision } network pool } }
      `,
    }),
    // Helps Next avoid caching upstream post requests
    cache: 'no-store',
  })
  const data = await response.json()
  const payload = data.data?.products ?? []
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
