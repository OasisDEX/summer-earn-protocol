import { Suspense } from 'react'

import { PortfolioBody } from '@/components/PortfolioBody'
import { ChainAwareLink } from '@/components/shell/ChainAwareLink'
import { Topbar } from '@/components/shell/Topbar'
import { PortfolioSkeleton } from '@/components/skeletons/PortfolioSkeleton'
import { Button } from '@/components/ui/Button'
import { type ChainId, resolveChainParam } from '@/types/chain'

// NOTE: not `'use cache'` — this page reads `searchParams` (`?chain=`), which
// is request-dynamic and incompatible with `'use cache'`. The chain-dependent
// body is deferred into a <Suspense>-wrapped loader; `Topbar` stays outside.
export default function PortfolioLandingPage({
  searchParams,
}: {
  searchParams: Promise<{ chain?: string }>
}) {
  return (
    <>
      <Topbar
        crumbs={[{ label: 'Portfolio' }]}
        actions={
          <ChainAwareLink href="/create">
            <Button>New strategy</Button>
          </ChainAwareLink>
        }
      />
      <Suspense fallback={<PortfolioSkeleton />}>
        <PortfolioLoader searchParams={searchParams} />
      </Suspense>
    </>
  )
}

async function PortfolioLoader({ searchParams }: { searchParams: Promise<{ chain?: string }> }) {
  const { chain } = await searchParams
  const chainId: ChainId = resolveChainParam(chain)
  return <PortfolioBody chainId={chainId} />
}
