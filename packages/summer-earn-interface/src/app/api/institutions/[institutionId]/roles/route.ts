import { NextResponse } from 'next/server'

import { CHAIN_INSTITUTIONS_SUBGRAPH_URLS } from '@/config/chains'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  request: Request,
  { params }: { params: Promise<{ institutionId: string }> },
) {
  const url = new URL(request.url)
  const chainId = (url.searchParams.get('chainId') ||
    '1') as keyof typeof CHAIN_INSTITUTIONS_SUBGRAPH_URLS
  const { institutionId } = await params
  const key = `roles:${chainId}:${institutionId}`
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
        query($institutionId: ID!) {
          roles(where: { institution: $institutionId }, orderBy: createdTimestamp, orderDirection: desc) {
            id
            name
            owner
            targetContract
            accessController
            createdTimestamp
            createdBlockNumber
            institution { id }
          }
        }
      `,
      variables: { institutionId },
    }),
    cache: 'no-store',
  })
  const json = await response.json()
  const data = json.data?.roles ?? []
  const payload = { chainId, institutionId, roles: data }
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
