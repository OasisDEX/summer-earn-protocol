import { headers } from 'next/headers'

import { RefreshButton } from '@/components/RefreshButton'
import VestingBatchTable from '@/components/VestingBatchTable'
import type { Environment } from '@/config/environments'

async function getData(chainId: string, environment: Environment = 'production') {
  // We fetch our own API route to utilize the caching logic defined there
  const host = headers().get('host')
  const protocol = process.env.NODE_ENV === 'development' ? 'http' : 'https'

  const res = await fetch(
    `${protocol}://${host}/api/vesting?chainId=${chainId}&environment=${environment}`,
    {
      next: { tags: ['vesting-data'] }, // Associate this fetch with the tag too
    },
  )

  if (!res.ok) {
    const error = await res.json().catch(() => ({ error: 'Failed to fetch data' }))
    throw new Error(error.error || 'Failed to fetch data')
  }

  return res.json()
}

export default async function VestingBatchPage({ params }: { params: { chainId: string } }) {
  const chainId = params.chainId || '8453'
  // Default to production, but the API route can accept environment as query param
  // For now, we'll use production. In the future, this could come from a cookie or header
  const environment: Environment = 'production'
  const { snapshots, timestamp } = await getData(chainId, environment)

  return (
    <main>
      <div className="max-w-9xl mx-auto space-y-6">
        <header className="space-y-4 pt-6">
          <div className="flex flex-col md:flex-row justify-between md:items-end gap-4">
            <div>
              <h1 className="text-3xl md:text-4xl font-extrabold text-white">
                Batch Vesting Snapshot{' '}
                <span className="text-blue-500 text-2xl align-top">Ultra</span>
              </h1>
              <p className="text-gray-300 text-sm mt-1">
                Data cached for 24h. Last Updated: {new Date(timestamp).toLocaleTimeString()}
              </p>
            </div>
            <div className="flex flex-col items-end gap-2">
              <RefreshButton lastUpdated={timestamp} />
            </div>
          </div>
        </header>

        {/* Pass data to Client Component for interactivity (Sorting) */}
        <VestingBatchTable initialSnapshots={snapshots} />
      </div>
    </main>
  )
}
