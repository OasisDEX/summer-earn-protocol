import { Suspense } from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { type Address, getAddress, isAddress } from 'viem'
import { base } from 'wagmi/chains'

import { PortfolioBody } from '@/components/PortfolioBody'
import { Topbar } from '@/components/shell/Topbar'
import { PortfolioSkeleton } from '@/components/skeletons/PortfolioSkeleton'
import { Button } from '@/components/ui/Button'
import { loadPortfolio } from '@/lib/server/loadPortfolio'
import { asChainId, type ChainId } from '@/types/chain'

export default function PortfolioByAddressPage({
  params,
}: {
  params: Promise<{ address: string }>
}) {
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
      <Suspense fallback={<PortfolioSkeleton />}>
        <PortfolioLoader params={params} />
      </Suspense>
    </>
  )
}

async function PortfolioLoader({ params }: { params: Promise<{ address: string }> }) {
  const { address: raw } = await params
  if (!isAddress(raw)) {
    notFound()
  }
  const owner = getAddress(raw) as Address
  const chainId: ChainId = asChainId(base.id)
  const initial = await loadPortfolio(chainId, owner)
  return (
    <PortfolioBody chainId={chainId} urlAddress={owner} initialStrategies={initial.strategies} />
  )
}
