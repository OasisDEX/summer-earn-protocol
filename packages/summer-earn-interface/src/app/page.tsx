'use client'

import { useState } from 'react'
import { ChainSelector } from '../components/ChainSelector'
import { EnvironmentSelector } from '../components/EnvironmentSelector'
import { FleetCard } from '../components/FleetCard'
import type { Environment } from '../config/environments'
import { HARBOR_COMMAND_ADDRESSES } from '../config/environments'
import { useActiveFleets } from '../hooks/useActiveFleets'
import type { ChainId } from '../types'

export default function Home() {
  const [selectedChain, setSelectedChain] = useState<ChainId>('1')
  const [selectedEnvironment, setSelectedEnvironment] = useState<Environment>('production')

  const { fleets, loading, error } = useActiveFleets({
    chainId: selectedChain,
    harborCommandAddress: HARBOR_COMMAND_ADDRESSES[selectedEnvironment][Number(selectedChain)],
  })

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-400 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center">Loading fleets...</div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gray-100 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-600">Error loading fleets: {error.message}</div>
        </div>
      </div>
    )
  }

  return (
    <main className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto">
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-4">Summer Earn Protocol</h1>
          <div className="flex flex-col gap-4">
            <EnvironmentSelector
              selectedEnvironment={selectedEnvironment}
              onChange={setSelectedEnvironment}
            />
            <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {fleets.map((fleet) => (
            <FleetCard
              key={fleet.address}
              fleetInfo={fleet}
              userInfo={null}
              assetDecimals={fleet.assetDecimals}
              assetSymbol={fleet.assetSymbol}
              chainId={selectedChain}
            />
          ))}
        </div>
      </div>
    </main>
  )
}
