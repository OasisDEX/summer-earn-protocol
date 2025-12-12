import { unstable_cache } from 'next/cache'
import { NextResponse } from 'next/server'

import type { Environment } from '@/config/environments'
import { fetchVestingData, replacer } from '@/lib/vesting-logic'

// Helper to serialize BigInts before caching
const serializeBigInts = (data: any): any => {
  return JSON.parse(JSON.stringify(data, replacer))
}

// Wrap logic in unstable_cache for 24h caching
// We serialize BigInts BEFORE caching since unstable_cache needs JSON-serializable data
const getCachedData = unstable_cache(
  async (chainId: number, environment: Environment) => {
    const data = await fetchVestingData(chainId, environment)
    return serializeBigInts(data)
  },
  ['vesting-data-cache'], // Internal cache key
  {
    revalidate: 86400, // 24 Hours
    tags: ['vesting-data'], // Tag for manual invalidation
  },
)

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const chainId = Number(searchParams.get('chainId')) || 8453
  const environment = (searchParams.get('environment') || 'production') as Environment

  try {
    const data = await getCachedData(chainId, environment)

    // Data is already serialized (BigInts are strings), so we can return it directly
    return NextResponse.json(data, {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error: any) {
    return NextResponse.json({ error: error.message }, { status: 500 })
  }
}
