'use client'

import { use } from 'react'
import Link from 'next/link'
import { base } from 'wagmi/chains'

import { ConnectButton } from '@/components/ConnectButton'
import { StrategyDetail } from '@/components/StrategyDetail'
import { Button } from '@/components/ui/Button'
import { asChainId, type ChainId } from '@/types/chain'

export default function StrategyDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = use(params)
  const chainId: ChainId = asChainId(base.id)

  return (
    <main className="mx-auto max-w-5xl px-6 py-10">
      <header className="mb-6 flex items-center justify-between gap-4">
        <Link href="/" className="text-sm text-surface-400 hover:text-surface-200">
          ← Back to strategies
        </Link>
        <div className="flex items-center gap-3">
          <Link href="/create">
            <Button variant="secondary">New strategy</Button>
          </Link>
          <ConnectButton />
        </div>
      </header>
      <StrategyDetail chainId={chainId} strategyId={id} />
    </main>
  )
}
