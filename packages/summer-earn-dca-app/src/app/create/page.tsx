'use client'

import Link from 'next/link'
import { base } from 'wagmi/chains'

import { ConnectButton } from '@/components/ConnectButton'
import { CreateStrategyForm } from '@/components/CreateStrategyForm'
import { asChainId, type ChainId } from '@/types/chain'

export default function CreatePage() {
  const chainId: ChainId = asChainId(base.id)

  return (
    <main className="mx-auto max-w-3xl px-6 py-10">
      <header className="mb-6 flex items-center justify-between gap-4">
        <Link href="/" className="text-sm text-surface-400 hover:text-surface-200">
          ← Back to strategies
        </Link>
        <ConnectButton />
      </header>
      <h1 className="mb-6 font-headline text-2xl font-semibold text-surface-50">
        New DCA strategy
      </h1>
      <CreateStrategyForm chainId={chainId} />
    </main>
  )
}
