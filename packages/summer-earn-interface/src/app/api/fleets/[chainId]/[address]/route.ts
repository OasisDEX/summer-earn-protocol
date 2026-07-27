import { NextResponse } from 'next/server'

import { ArksOverviewError } from '@/lib/arks-overview'
import { getFleetDetailPayload } from '@/lib/domino/tasks/fleet-detail-task'

const TTL_MS = 30 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  request: Request,
  { params }: { params: Promise<{ chainId: string; address: string }> },
) {
  const { chainId, address } = await params
  const url = new URL(request.url)
  const user = url.searchParams.get('user')
  const key = `${chainId}:${address}:${user ?? ''}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  try {
    const payload = await getFleetDetailPayload(chainId, address, user)
    cache.set(key, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload)
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
