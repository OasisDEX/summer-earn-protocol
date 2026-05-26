import { Suspense } from 'react'
import Link from 'next/link'
import { base } from 'wagmi/chains'

import { Topbar } from '@/components/shell/Topbar'
import { StrategyDetailSkeleton } from '@/components/skeletons/StrategyDetailSkeleton'
import { StrategyDetail } from '@/components/StrategyDetail'
import { Button } from '@/components/ui/Button'
import { loadStrategyDetail } from '@/lib/server/loadStrategyDetail'
import { asChainId, type ChainId } from '@/types/chain'

const BackAction = (
  <Link href="/portfolio">
    <Button variant="ghost">← Back</Button>
  </Link>
)

export default function StrategyDetailPage({ params }: { params: Promise<{ id: string }> }) {
  return (
    <>
      <Suspense
        fallback={
          <Topbar
            crumbs={[{ href: '/portfolio', label: 'Portfolio' }, { label: '…' }]}
            actions={BackAction}
          />
        }
      >
        <StrategyTopbar params={params} />
      </Suspense>
      <Suspense fallback={<StrategyDetailSkeleton />}>
        <StrategyLoader params={params} />
      </Suspense>
    </>
  )
}

async function StrategyTopbar({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  return (
    <Topbar
      crumbs={[{ href: '/portfolio', label: 'Portfolio' }, { label: `#${id}` }]}
      actions={BackAction}
    />
  )
}

async function StrategyLoader({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const chainId: ChainId = asChainId(base.id)
  const initial = await loadStrategyDetail(chainId, id)
  return <StrategyDetail chainId={chainId} strategyId={id} initial={initial} />
}
