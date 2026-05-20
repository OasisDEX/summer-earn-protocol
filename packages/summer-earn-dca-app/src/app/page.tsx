'use client'

import Link from 'next/link'
import { base } from 'wagmi/chains'

import { ConnectButton } from '@/components/ConnectButton'
import { StrategyList } from '@/components/StrategyList'
import { Button } from '@/components/ui/Button'
import { asChainId, type ChainId } from '@/types/chain'

export default function Dashboard() {
  const chainId: ChainId = asChainId(base.id)

  return (
    <main className="mx-auto max-w-5xl px-6 py-10">
      <header className="mb-8 flex items-center justify-between gap-4">
        <div>
          <h1 className="font-headline text-2xl font-semibold text-surface-50">Summer Earn DCA</h1>
          <p className="text-sm text-surface-400">
            Recurring dollar-cost-averaging strategies on Base.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <Link href="/create">
            <Button>New strategy</Button>
          </Link>
          <ConnectButton />
        </div>
      </header>
      <StrategyList chainId={chainId} />
    </main>
  )
}
