'use client'

import { use } from 'react'

import { RoundsVaultDashboard } from '@/components/rounds-vault/RoundsVaultDashboard'
import { PageHeader } from '@/components/ui'
import { useSyncWalletChain } from '@/hooks/useSyncWalletChain'
import type { ChainId } from '@/types'

export default function RoundsVaultPage({ params }: { params: Promise<{ chainId: string }> }) {
  const { chainId } = use(params)
  useSyncWalletChain(chainId as ChainId)

  return (
    <main className="min-h-screen p-8">
      <div className="max-w-7xl mx-auto space-y-8">
        <PageHeader
          title="Rounds Vault Dashboard"
          description={
            <>
              Interact with the WisdomTree Rounds Vaults on chain {chainId}. Deposit assets or
              shares into the locked vaults and exchange your receipts.
            </>
          }
        />

        <RoundsVaultDashboard chainId={chainId as ChainId} />
      </div>
    </main>
  )
}
