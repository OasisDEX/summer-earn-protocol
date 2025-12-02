import { NextResponse } from 'next/server'

import { fetchAllVaults } from '../utils'

/**
 * Cron endpoint to refresh vault APR cache every hour
 * Can be called by Vercel Cron Jobs or external cron service
 *
 * Vercel Cron Job configuration (vercel.json):
 * {
 *   "crons": [{
 *     "path": "/api/vault-apr/cron",
 *     "schedule": "0 * * * *"
 *   }]
 * }
 */
export async function GET(request: Request) {
  // Optional: Add authentication/authorization check here
  const authHeader = request.headers.get('authorization')
  const cronSecret = process.env.CRON_SECRET

  if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  try {
    // Force refresh the cache
    const data = await fetchAllVaults(true)

    return NextResponse.json({
      success: true,
      vaultsCount: data.reduce((sum, chain) => sum + chain.vaults.length, 0),
      chains: data.map((d) => d.chainId),
      timestamp: Date.now(),
    })
  } catch (error) {
    console.error('Error refreshing vault APR cache:', error)
    return NextResponse.json(
      { error: 'Failed to refresh cache', details: String(error) },
      { status: 500 },
    )
  }
}
