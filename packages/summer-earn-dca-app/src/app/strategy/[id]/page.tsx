'use client'

import { use } from 'react'
import Link from 'next/link'
import { base } from 'wagmi/chains'

import { Topbar } from '@/components/shell/Topbar'
import { StrategyDetail } from '@/components/StrategyDetail'
import { Button } from '@/components/ui/Button'
import { asChainId, type ChainId } from '@/types/chain'

export default function StrategyDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params)
  const chainId: ChainId = asChainId(base.id)

  return (
    <>
      <Topbar
        crumbs={[
          { href: '/', label: 'Portfolio' },
          { label: `#${id}` },
        ]}
        actions={
          <Link href="/">
            <Button variant="ghost">← Back</Button>
          </Link>
        }
      />
      <StrategyDetail chainId={chainId} strategyId={id} />
    </>
  )
}
