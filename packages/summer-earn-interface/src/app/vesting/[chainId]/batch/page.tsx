import { headers } from 'next/headers'
import Link from 'next/link'

import { RefreshButton } from '@/components/RefreshButton'
import VestingBatchTable from '@/components/VestingBatchTable'
import type { Environment } from '@/config/environments'

async function getData(chainId: string, environment: Environment = 'production') {
  // We fetch our own API route to utilize the caching logic defined there
  const host = (await headers()).get('host')
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

export default async function VestingBatchPage({
  params,
}: {
  params: Promise<{ chainId: string }>
}) {
  const { chainId } = await params
  const { snapshots, timestamp } = await getData(chainId)

  return (
    <main className="w-full min-h-screen bg-charcoal-900 p-8">
      <header className="space-y-4">
        <div className="flex items-center gap-2 text-sm text-slate-500">
          <Link href="/" className="hover:text-white transition-colors">
            Admin
          </Link>
          <span>›</span>
          <span className="text-slate-400">Batch Vesting</span>
        </div>
        <div className="flex flex-col md:flex-row justify-between md:items-end gap-4">
          <div>
            <h1 className="text-2xl font-bold text-white">Batch Vesting</h1>
            <p className="text-slate-500 text-sm mt-1">
              Last updated: {new Date(timestamp).toLocaleTimeString()}
            </p>
          </div>
          <RefreshButton lastUpdated={timestamp} />
        </div>
      </header>

      <VestingBatchTable initialSnapshots={snapshots} chainId={chainId} />
    </main>
  )
}
