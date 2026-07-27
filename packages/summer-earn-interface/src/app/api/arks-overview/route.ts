import { NextResponse } from 'next/server'

import { type Environment } from '@/config/environments'
import { getAllArksOverview } from '@/lib/arks-overview'

const TTL_MS = 2 * 60 * 1000 // 2 minutes — shorter than /api/fleets since this tracks active wind-downs
const cache = new Map<Environment, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const environment = (url.searchParams.get('environment') || 'production') as Environment

    const now = Date.now()
    const cached = cache.get(environment)
    if (cached && cached.expiry > now) {
      return NextResponse.json(cached.data)
    }

    const chains = await getAllArksOverview(environment)
    const payload = { environment, chains, lastUpdated: now }
    cache.set(environment, { data: payload, expiry: now + TTL_MS })

    return NextResponse.json(payload)
  } catch (err) {
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
