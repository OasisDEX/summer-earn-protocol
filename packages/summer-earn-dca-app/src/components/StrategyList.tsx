'use client'

import { useState } from 'react'
import Link from 'next/link'
import { useAccount } from 'wagmi'

import { StrategyCard } from '@/components/StrategyCard'
import { Button } from '@/components/ui/Button'
import { Segmented } from '@/components/ui/Segmented'
import { useStrategiesByOwner } from '@/hooks/useDcaSubgraph'
import type { SubgraphStrategy } from '@/lib/subgraph/types'
import type { ChainId } from '@/types/chain'

type StatusFilter = 'ALL' | 'ACTIVE' | 'PAUSED' | 'COMPLETED' | 'CANCELLED'

function counts(strategies: SubgraphStrategy[]): Record<StatusFilter, number> {
  const result: Record<StatusFilter, number> = {
    ALL: strategies.length,
    ACTIVE: 0,
    PAUSED: 0,
    COMPLETED: 0,
    CANCELLED: 0,
  }
  for (const s of strategies) {
    result[s.status as Exclude<StatusFilter, 'ALL'>] += 1
  }
  return result
}

export function StrategyList({ chainId }: { chainId: ChainId }) {
  const { address } = useAccount()
  const { data: strategies, isLoading, error } = useStrategiesByOwner(chainId, address)
  const [filter, setFilter] = useState<StatusFilter>('ALL')

  if (!address) {
    return (
      <div className="rounded-lg border border-dashed border-[var(--border)] p-12 text-center text-[var(--text-2)]">
        Connect your wallet to view DCA strategies.
      </div>
    )
  }

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
        {[0, 1, 2].map((i) => (
          <div key={i} className="skel h-[240px] rounded-lg" />
        ))}
      </div>
    )
  }

  if (error) {
    return (
      <div className="rounded-lg border border-[var(--danger)]/40 bg-[var(--danger)]/10 p-4 text-sm text-[var(--danger)]">
        Could not load strategies: {(error as Error).message}
      </div>
    )
  }

  const all = strategies ?? []
  if (all.length === 0) {
    return (
      <div className="grid place-items-center gap-3 rounded-lg border border-dashed border-[var(--border)] p-12 text-center">
        <div
          className="grid h-[72px] w-[72px] place-items-center rounded-[22px] bg-[var(--surface)] text-[var(--pink)]"
          style={{ boxShadow: '0 0 0 1px var(--border-faint)' }}
        >
          <span className="text-2xl">~</span>
        </div>
        <h2 className="h2">Start your first wave</h2>
        <p className="text-sm text-[var(--text-3)]">
          Schedule recurring auto-swaps from a yield-earning vault into a target asset.
        </p>
        <Link href="/create" className="mt-1">
          <Button size="lg">Create a strategy</Button>
        </Link>
      </div>
    )
  }

  const filtered = filter === 'ALL' ? all : all.filter((s) => s.status === filter)
  const c = counts(all)

  return (
    <>
      <div className="mb-4 flex items-center justify-between">
        <Segmented<StatusFilter>
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'ALL', label: `All ${c.ALL}` },
            { value: 'ACTIVE', label: `Active ${c.ACTIVE}` },
            { value: 'PAUSED', label: `Paused ${c.PAUSED}` },
            { value: 'COMPLETED', label: `Completed ${c.COMPLETED}` },
            { value: 'CANCELLED', label: `Cancelled ${c.CANCELLED}` },
          ]}
        />
      </div>
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3">
        {filtered.map((s) => (
          <StrategyCard key={s.id} chainId={chainId} strategy={s} />
        ))}
      </div>
    </>
  )
}
