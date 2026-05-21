import Link from 'next/link'
import { base } from 'wagmi/chains'

import { PortfolioBody } from '@/components/PortfolioBody'
import { Topbar } from '@/components/shell/Topbar'
import { Button } from '@/components/ui/Button'
import { asChainId, type ChainId } from '@/types/chain'

export default function PortfolioLandingPage() {
  const chainId: ChainId = asChainId(base.id)
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
      <PortfolioBody chainId={chainId} />
    </>
  )
}
