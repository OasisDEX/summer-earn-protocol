import { headers } from 'next/headers'
import Link from 'next/link'

import { RefreshButton } from '@/components/RefreshButton'
import { PageHeader } from '@/components/ui'
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
    <main className="w-full min-h-screen p-8">
      <header>
        <div className="flex items-center gap-2 text-sm text-on-surface-variant">
          <Link href="/" className="hover:text-on-surface transition-colors">
            Admin
          </Link>
          <span>›</span>
          <span className="text-on-surface-variant">Batch Vesting</span>
        </div>
        <PageHeader
          title="Batch Vesting"
          description={`Last updated: ${new Date(timestamp).toLocaleTimeString()}`}
          actions={<RefreshButton lastUpdated={timestamp} />}
        />
      </header>

      <VestingBatchTable initialSnapshots={snapshots} chainId={chainId} />
    </main>
  )
}
