'use client'

import Link from 'next/link'
import { useAccount } from 'wagmi'
import { base } from 'wagmi/chains'

import { PortfolioKpis } from '@/components/dashboard/PortfolioKpis'
import { Topbar } from '@/components/shell/Topbar'
import { StrategyList } from '@/components/StrategyList'
import { Button } from '@/components/ui/Button'
import { useStrategiesByOwner } from '@/hooks/useDcaSubgraph'
import { asChainId, type ChainId } from '@/types/chain'

export default function Dashboard() {
  const chainId: ChainId = asChainId(base.id)
  const { address } = useAccount()
  const { data: strategies } = useStrategiesByOwner(chainId, address)
  const active = (strategies ?? []).filter((s) => s.status === 'ACTIVE').length
  const total = strategies?.length ?? 0

  return (
    <>
      <Topbar
        crumbs={[{ label: 'Portfolio' }]}
        actions={
          <Link href="/create">
            <Button>New strategy</Button>
          </Link>
        }
      />
      <div className="page">
        <header className="mb-7 flex flex-wrap items-end justify-between gap-3">
          <div>
            <h1 className="h1">Portfolio</h1>
            <p className="mt-1 font-mono text-xs text-[var(--text-3)]">
              {active} active · {total} total
            </p>
          </div>
        </header>

        {address && strategies && <PortfolioKpis chainId={chainId} strategies={strategies} />}

        <div className="mt-8">
          <StrategyList chainId={chainId} />
        </div>
      </div>
    </>
  )
}
