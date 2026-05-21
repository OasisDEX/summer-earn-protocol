import Link from 'next/link'
import { base } from 'wagmi/chains'

import { PortfolioBody } from '@/components/PortfolioBody'
import { Topbar } from '@/components/shell/Topbar'
import { Button } from '@/components/ui/Button'
import { asChainId, type ChainId } from '@/types/chain'

// `/portfolio` with no owner segment — connect-wallet landing. On wallet
// connect, <PortfolioBody> pushes the address into the path so the next
// paint is the server-rendered `/portfolio/{address}` page.
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
