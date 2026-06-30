import { Suspense } from 'react'

import { CreateStrategyForm } from '@/components/CreateStrategyForm'
import { Topbar } from '@/components/shell/Topbar'
import { type ChainId, resolveChainParam } from '@/types/chain'

// NOTE: not `'use cache'` — this page reads `searchParams` (`?chain=`), which
// is request-dynamic and incompatible with `'use cache'`. The chain-dependent
// body is deferred into a <Suspense>-wrapped loader; `Topbar` stays outside.
export default function CreatePage({
  searchParams,
}: {
  searchParams: Promise<{ chain?: string }>
}) {
  return (
    <>
      <Topbar crumbs={[{ href: '/portfolio', label: 'Portfolio' }, { label: 'New strategy' }]} />
      <div className="page">
        <h1 className="h1 mb-6">New strategy</h1>
        <Suspense>
          <CreateLoader searchParams={searchParams} />
        </Suspense>
      </div>
    </>
  )
}

async function CreateLoader({ searchParams }: { searchParams: Promise<{ chain?: string }> }) {
  const { chain } = await searchParams
  const chainId: ChainId = resolveChainParam(chain)
  return <CreateStrategyForm chainId={chainId} />
}
