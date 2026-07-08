import { NextResponse } from 'next/server'

import { type Environment } from '@/config/environments'
import { ArksOverviewError, getFleetsForChain } from '@/lib/arks-overview'

const TTL_MS = 10 * 60 * 1000 // 10 minutes
const cache = new Map<string, { data: unknown; expiry: number }>()

function getCacheKey(params: URLSearchParams): string {
  const env = params.get('environment') || 'production'
  const chainId = params.get('chainId') || '1'
  return `${env}:${chainId}`
}

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const params = url.searchParams
    const chainId = params.get('chainId') || '1'
    const environment = (params.get('environment') || 'production') as Environment

    const key = getCacheKey(params)
    const now = Date.now()
    const cached = cache.get(key)
    if (cached && cached.expiry > now) {
      return NextResponse.json(cached.data)
    }

    const fleets = await getFleetsForChain(chainId, environment)
    const payload = { chainId, environment, fleets }
    cache.set(key, { data: payload, expiry: now + TTL_MS })

    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
