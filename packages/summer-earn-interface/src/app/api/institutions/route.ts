import { NextResponse } from 'next/server'

import { CHAIN_INSTITUTIONS_SUBGRAPH_URLS } from '@/config/chains'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  const url = new URL(request.url)
  const chainId = (url.searchParams.get('chainId') ||
    '1') as keyof typeof CHAIN_INSTITUTIONS_SUBGRAPH_URLS
  const key = `institutions:${chainId}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const endpoint = CHAIN_INSTITUTIONS_SUBGRAPH_URLS[chainId]
  if (!endpoint) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        query {
          institutions(orderBy: createdTimestamp, orderDirection: desc) {
            id
            configurationManager
            protocolAccessManager
            admiralsQuarters
            harborCommand
            active
            createdTimestamp
            createdBlockNumber
          }
        }
      `,
    }),
    cache: 'no-store',
  })
  const json = await response.json()
  const data = json.data?.institutions ?? []
  const payload = { chainId, institutions: data }
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
