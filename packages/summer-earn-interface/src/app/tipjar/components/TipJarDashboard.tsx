'use client'

import { PageHeader } from '../../../components/ui'
import { TIPJAR_CHAINS } from '../lib/tipJarConfig'
import { TipJarChainSection } from './TipJarChainSection'

export function TipJarDashboard() {
  return (
    <div className="max-w-7xl mx-auto px-6 py-8">
      <PageHeader
        title="TipJar"
        description={
          <>
            Tip stream configuration and pending shakeable amounts for every TipJar across all
            chains. Use <span className="text-on-surface font-medium">Shake</span> to distribute a
            single fleet commander&apos;s accrued tips, or{' '}
            <span className="text-on-surface font-medium">Shake all</span> for the whole chain.
            Submitting an action automatically switches your connected wallet to that chain.{' '}
            <span className="text-on-surface-variant/80">
              Shaking requires the keeper role — other wallets will revert.
            </span>
          </>
        }
      />

      <div className="space-y-10">
        {TIPJAR_CHAINS.map((chainId) => (
          <TipJarChainSection key={chainId} chainId={chainId} />
        ))}
      </div>
    </div>
  )
}
