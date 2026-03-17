import { NextResponse } from 'next/server'

import { CHAIN_GOVERNANCE_SUBGRAPH_URLS } from '@/config/chains'
import { resolveRole } from '@/utils/roleResolver'

const TTL_MS = 5 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request, { params }: { params: Promise<{ chainId: string }> }) {
  const url = new URL(request.url)
  const { chainId } = await params
  const activeOnly = url.searchParams.get('activeOnly') === 'true'
  const key = `roles:${chainId}:${activeOnly}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  const endpoint = CHAIN_GOVERNANCE_SUBGRAPH_URLS[chainId]
  if (!endpoint) return NextResponse.json({ error: 'Unsupported chainId' }, { status: 400 })

  const query = activeOnly
    ? `
        query {
          roles(where: { active: true }, orderBy: createdTimestamp, orderDirection: desc, first:1000) {
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
          roles(orderBy: createdTimestamp, orderDirection: desc, first:1000) {
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
  const allRoles = json.data?.roles ?? []

  // Resolve role names and filter out unresolved roles
  const roles = allRoles
    .map((role: { name: string; [key: string]: unknown }) => {
      const resolved = resolveRole(role)
      if (resolved.resolved) {
        return { ...role, name: resolved.name }
      }
      return null
    })
    .filter((role: { name: string } | null) => role !== null)
  roles.sort((a, b) => b.name.localeCompare(a.name))
  const payload = { chainId, roles }
  cache.set(key, { data: payload, expiry: now + TTL_MS })
  return NextResponse.json(payload)
}
