'use client'

import Link from 'next/link'
import { useAccount } from 'wagmi'

import { StrategyCard } from '@/components/StrategyCard'
import { Button } from '@/components/ui/Button'
import { useStrategiesByOwner } from '@/hooks/useDcaSubgraph'
import type { ChainId } from '@/types/chain'

export function StrategyList({ chainId }: { chainId: ChainId }) {
  const { address } = useAccount()
  const { data: strategies, isLoading, error } = useStrategiesByOwner(chainId, address)

  if (!address) {
    return (
      <div className="rounded-lg border border-dashed border-surface-700 p-8 text-center text-surface-300">
        Connect your wallet to view DCA strategies.
      </div>
    )
  }

  if (isLoading) {
    return <div className="text-surface-300">Loading strategies…</div>
  }

  if (error) {
    return (
      <div className="rounded-lg border border-danger/40 bg-danger/10 p-4 text-sm text-danger">
        Could not load strategies: {(error as Error).message}
      </div>
    )
  }

  if (!strategies || strategies.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-surface-700 p-8 text-center">
        <p className="text-surface-300">You don&apos;t have any DCA strategies yet.</p>
        <Link href="/create" className="mt-3 inline-block">
          <Button>Create your first strategy</Button>
        </Link>
      </div>
    )
  }

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      {strategies.map((s) => (
        <StrategyCard key={s.id} chainId={chainId} strategy={s} />
      ))}
    </div>
  )
}
