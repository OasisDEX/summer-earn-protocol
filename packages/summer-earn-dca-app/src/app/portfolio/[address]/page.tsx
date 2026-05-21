import Link from 'next/link'
import { notFound } from 'next/navigation'
import { type Address, getAddress, isAddress } from 'viem'
import { base } from 'wagmi/chains'

import { PortfolioBody } from '@/components/PortfolioBody'
import { Topbar } from '@/components/shell/Topbar'
import { Button } from '@/components/ui/Button'
import { loadPortfolio } from '@/lib/server/loadPortfolio'
import { asChainId, type ChainId } from '@/types/chain'

export default async function PortfolioByAddressPage({
  params,
}: {
  params: Promise<{ address: string }>
}) {
  const { address: raw } = await params
  if (!isAddress(raw)) {
    notFound()
  }
  const owner = getAddress(raw) as Address
  const chainId: ChainId = asChainId(base.id)
  const initial = await loadPortfolio(chainId, owner)

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
      <PortfolioBody chainId={chainId} urlAddress={owner} initialStrategies={initial.strategies} />
    </>
  )
}
