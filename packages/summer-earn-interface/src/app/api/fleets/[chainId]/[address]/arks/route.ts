import { NextResponse } from 'next/server'

import { ArksOverviewError, getArksForFleet } from '@/lib/arks-overview'

const TTL_MS = 10 * 60 * 1000
const cache = new Map<string, { data: unknown; expiry: number }>()

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ chainId: string; address: string }> },
) {
  const { chainId, address } = await params
  const key = `arks:${chainId}:${address}`
  const now = Date.now()
  const cached = cache.get(key)
  if (cached && cached.expiry > now) return NextResponse.json(cached.data)

  try {
    const payload = await getArksForFleet(chainId, address as `0x${string}`)
    cache.set(key, { data: payload, expiry: now + TTL_MS })
    return NextResponse.json(payload)
  } catch (err) {
    if (err instanceof ArksOverviewError) {
      return NextResponse.json({ error: err.message }, { status: err.status })
    }
    return NextResponse.json({ error: (err as Error).message }, { status: 500 })
  }
}
