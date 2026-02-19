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
  const key = `vaults:${chainId}:${institutionId}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const endpoint = CHAIN_INSTITUTIONS_SUBGRAPH_URLS[chainId]
  if (!endpoint) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  // Assuming the institutions subgraph exposes Vault entities with relation to institution
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      query: `
        query($institutionId: ID!) {
          vaults(where: { institution: $institutionId }) {
id
    name
    inputToken {
      id
    }
    createdTimestamp
    createdBlockNumber
    institution {
      id
    }
          }
        }
      `,
      variables: { institutionId },
    }),
    cache: 'no-store',
  })
  const json = await response.json()
  const data = json.data?.vaults ?? []
  const payload = { chainId, institutionId, vaults: data }
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
