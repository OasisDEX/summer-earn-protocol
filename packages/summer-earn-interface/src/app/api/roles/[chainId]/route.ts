import { NextResponse } from 'next/server'

import { CHAIN_GOVERNANCE_SUBGRAPH_URLS } from '@/config/chains'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  request: Request,
  { params }: { params: { chainId: string } },
) {
  const url = new URL(request.url)
  const chainId = params.chainId as keyof typeof CHAIN_GOVERNANCE_SUBGRAPH_URLS
  const activeOnly = url.searchParams.get('activeOnly') === 'true'
  const key = `roles:${chainId}:${activeOnly}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const endpoint = CHAIN_GOVERNANCE_SUBGRAPH_URLS[chainId]
  if (!endpoint) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const whereClause = activeOnly ? 'where: { active: true }' : ''

  const query = activeOnly
    ? `
        query {
          roles(where: { active: true }, orderBy: createdTimestamp, orderDirection: desc) {
            id
            name
            owner
            targetContract
            accessController
            active
            createdTimestamp
            createdBlockNumber
            events(orderBy: timestamp, orderDirection: desc, first: 1) {
              id
              hash
              logIndex
              timestamp
              blockNumber
              caller
              action
            }
          }
        }
      `
    : `
        query {
          roles(orderBy: createdTimestamp, orderDirection: desc) {
            id
            name
            owner
            targetContract
            accessController
            active
            createdTimestamp
            createdBlockNumber
            events(orderBy: timestamp, orderDirection: desc, first: 1) {
              id
              hash
              logIndex
              timestamp
              blockNumber
              caller
              action
            }
          }
        }
      `

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query,
    }),
    cache: 'no-store',
  })
  const json = await response.json()
  const data = json.data?.roles ?? []
  const payload = { chainId, roles: data }
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
