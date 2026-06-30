import { Suspense } from 'react'
import Link from 'next/link'
import { notFound } from 'next/navigation'
import { type Address, getAddress, isAddress } from 'viem'

import { PortfolioBody } from '@/components/PortfolioBody'
import { Topbar } from '@/components/shell/Topbar'
import { PortfolioSkeleton } from '@/components/skeletons/PortfolioSkeleton'
import { Button } from '@/components/ui/Button'
import { loadPortfolio } from '@/lib/server/loadPortfolio'
import { type ChainId, resolveChainParam } from '@/types/chain'

export default function PortfolioByAddressPage({
  params,
  searchParams,
}: {
  params: Promise<{ address: string }>
  searchParams: Promise<{ chain?: string }>
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
        <PortfolioLoader params={params} searchParams={searchParams} />
      </Suspense>
    </>
  )
}

async function PortfolioLoader({
  params,
  searchParams,
}: {
  params: Promise<{ address: string }>
  searchParams: Promise<{ chain?: string }>
}) {
  const { address: raw } = await params
  const { chain } = await searchParams
  if (!isAddress(raw)) {
    notFound()
  }
  const owner = getAddress(raw) as Address
  const chainId: ChainId = resolveChainParam(chain)
  const initial = await loadPortfolio(chainId, owner)
  return (
    <PortfolioBody chainId={chainId} urlAddress={owner} initialStrategies={initial.strategies} />
  )
}
