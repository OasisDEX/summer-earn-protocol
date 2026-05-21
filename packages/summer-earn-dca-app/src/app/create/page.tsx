'use client'

import { base } from 'wagmi/chains'

import { CreateStrategyForm } from '@/components/CreateStrategyForm'
import { Topbar } from '@/components/shell/Topbar'
import { asChainId, type ChainId } from '@/types/chain'

export default function CreatePage() {
  const chainId: ChainId = asChainId(base.id)

  return (
    <>
      <Topbar crumbs={[{ href: '/', label: 'Portfolio' }, { label: 'New strategy' }]} />
      <div className="page">
        <h1 className="h1 mb-6">New strategy</h1>
        <CreateStrategyForm chainId={chainId} />
      </div>
    </>
  )
}
