'use client'

import { use } from 'react'

import { RoundsVaultDashboard } from '@/components/rounds-vault/RoundsVaultDashboard'
import type { ChainId } from '@/types'

export default function RoundsVaultPage({ params }: { params: Promise<{ chainId: string }> }) {
  const { chainId } = use(params)

  return (
    <main className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-7xl mx-auto space-y-8">
        <div>
          <h1 className="text-3xl font-bold text-white mb-2">Rounds Vault Dashboard</h1>
          <p className="text-gray-300">
            Interact with the WisdomTree Rounds Vaults on chain {chainId}. Deposit assets or shares
            into the locked vaults and exchange your receipts.
          </p>
        </div>

        <RoundsVaultDashboard chainId={chainId as ChainId} />
      </div>
    </main>
  )
}
