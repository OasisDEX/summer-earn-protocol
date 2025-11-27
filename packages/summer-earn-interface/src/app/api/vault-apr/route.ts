import { NextResponse } from 'next/server'

import { cache, fetchAllVaults } from './utils'

export async function GET(request: Request) {
  const url = new URL(request.url)
  const forceRefresh = url.searchParams.get('refresh') === 'true'

  try {
    const data = await fetchAllVaults(forceRefresh)
    const cached = cache.get('all-vaults-apr')

    return NextResponse.json({
      data,
      cached: !forceRefresh && cached !== undefined,
      lastUpdated: cached?.lastUpdated ?? Date.now(),
    })
  } catch (error) {
    console.error('Error fetching vault APR data:', error)
    return NextResponse.json({ error: 'Failed to fetch vault APR data' }, { status: 500 })
  }
}
