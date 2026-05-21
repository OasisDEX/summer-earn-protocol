import Link from 'next/link'
import { base } from 'wagmi/chains'

import { Topbar } from '@/components/shell/Topbar'
import { StrategyDetail } from '@/components/StrategyDetail'
import { Button } from '@/components/ui/Button'
import { loadStrategyDetail } from '@/lib/server/loadStrategyDetail'
import { asChainId, type ChainId } from '@/types/chain'

// Async Server Component — pre-resolves the subgraph row + initial in/out
// price series on the server so the client subtree paints with data on the
// first render instead of waiting on `subgraph row → price queries` round-
// trips after hydration. TanStack still owns refetch, range changes, and
// any wallet-touching work in the client component.
export default async function StrategyDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const chainId: ChainId = asChainId(base.id)
  const initial = await loadStrategyDetail(chainId, id)

  return (
    <>
      <Topbar
        crumbs={[{ href: '/portfolio', label: 'Portfolio' }, { label: `#${id}` }]}
        actions={
          <Link href="/portfolio">
            <Button variant="ghost">← Back</Button>
          </Link>
        }
      />
      <StrategyDetail chainId={chainId} strategyId={id} initial={initial} />
    </>
  )
}
