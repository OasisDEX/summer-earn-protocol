'use client'

import { TIPJAR_CHAINS } from '../lib/tipJarConfig'
import { TipJarChainSection } from './TipJarChainSection'

export function TipJarDashboard() {
  return (
    <div className="max-w-7xl mx-auto px-6 py-8">
      <header className="mb-8">
        <h1 className="text-3xl font-bold text-white mb-2">TipJar</h1>
        <p className="text-slate-400 max-w-3xl">
          Tip stream configuration and pending shakeable amounts for every TipJar across all chains.
          Use <span className="text-white font-medium">Shake</span> to distribute a single fleet
          commander&apos;s accrued tips, or{' '}
          <span className="text-white font-medium">Shake all</span> for the whole chain. Submitting
          an action automatically switches your connected wallet to that chain.{' '}
          <span className="text-slate-500">
            Shaking requires the keeper role — other wallets will revert.
          </span>
        </p>
      </header>

      <div className="space-y-10">
        {TIPJAR_CHAINS.map((chainId) => (
          <TipJarChainSection key={chainId} chainId={chainId} />
        ))}
      </div>
    </div>
  )
}
