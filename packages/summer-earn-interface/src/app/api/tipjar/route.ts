import { NextResponse } from 'next/server'

import { ArksOverviewError } from '@/lib/arks-overview'
import { getTipjarPayload } from '@/lib/domino/tasks/tipjar-task'
import type { ChainId } from '@/types'

// Pending amounts drift as fees accrue, so keep the cache short. A successful
// shake refetches with `?refresh=true` to bypass it entirely.
const TTL_MS = 20 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(request: Request) {
  try {
    const url = new URL(request.url)
    const chainId = (url.searchParams.get('chainId') || '1') as ChainId
    const refresh = url.searchParams.get('refresh') === 'true'

    const now = Date.now()
    if (!refresh) {
      const cached = cache.get(chainId)
      if (cached && cached.expiry > now) {
        return NextResponse.json(cached.data)
      }
    }

    const payload = await getTipjarPayload(chainId)
    cache.set(chainId, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload, { status: 200 })
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
