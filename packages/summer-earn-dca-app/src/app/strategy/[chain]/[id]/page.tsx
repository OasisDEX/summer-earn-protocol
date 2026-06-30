import { Suspense } from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'

import { Topbar } from '@/components/shell/Topbar'
import { StrategyDetailSkeleton } from '@/components/skeletons/StrategyDetailSkeleton'
import { StrategyDetail } from '@/components/StrategyDetail'
import { Button } from '@/components/ui/Button'
import { loadStrategyDetail } from '@/lib/server/loadStrategyDetail'
import { chainIdFromSlug } from '@/types/chain'

function backHref(chain: string): string {
  return `/portfolio?chain=${chain}`
}

export default function StrategyDetailPage({
  params,
}: {
  params: Promise<{ chain: string; id: string }>
}) {
  return (
    <>
      <Suspense
        fallback={
          <Topbar
            crumbs={[{ href: '/portfolio', label: 'Portfolio' }, { label: '…' }]}
            actions={
              <Link href="/portfolio">
                <Button variant="ghost">← Back</Button>
              </Link>
            }
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

async function StrategyTopbar({ params }: { params: Promise<{ chain: string; id: string }> }) {
  const { chain, id } = await params
  const cid = chainIdFromSlug(chain)
  if (!cid) notFound()
  return (
    <Topbar
      crumbs={[{ href: backHref(chain), label: 'Portfolio' }, { label: `#${id}` }]}
      actions={
        <Link href={backHref(chain)}>
          <Button variant="ghost">← Back</Button>
        </Link>
      }
    />
  )
}

async function StrategyLoader({ params }: { params: Promise<{ chain: string; id: string }> }) {
  const { chain, id } = await params
  const cid = chainIdFromSlug(chain)
  if (!cid) notFound()
  const initial = await loadStrategyDetail(cid, id)
  return <StrategyDetail chainId={cid} strategyId={id} initial={initial} />
}
