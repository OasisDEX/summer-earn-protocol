'use client'

import { useState } from 'react'
import { ChainSelector } from '../components/ChainSelector'
import { EnvironmentSelector } from '../components/EnvironmentSelector'
import { FleetCard } from '../components/FleetCard'
import { HARBOR_COMMAND_ADDRESSES } from '../config/environments'
import { useActiveFleets } from '../hooks/useActiveFleets'
import { useEnvironment } from '../hooks/useEnvironment'
import type { ChainId } from '../types'

export default function Home() {
  const [selectedChain, setSelectedChain] = useState<ChainId>('1')
  const { environment, setEnvironment } = useEnvironment()

  const { fleets, loading, error } = useActiveFleets({
    chainId: selectedChain,
    harborCommandAddress: HARBOR_COMMAND_ADDRESSES[environment][Number(selectedChain)],
  })

  if (loading) {
    return (
      <div className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-gray-300">Loading fleets...</div>
        </div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="min-h-screen bg-black p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-400">Error loading fleets: {error.message}</div>
        </div>
      </div>
    )
  }

  return (
    <main className="min-h-screen bg-black p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Summer Earn Protocol</h1>
          <p className="text-gray-300 mb-6">
            Manage your DeFi positions and protocol roles across multiple chains
          </p>
          
          <div className="bg-gray-900 p-6 rounded-lg">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <EnvironmentSelector selectedEnvironment={environment} onChange={setEnvironment} />
              <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
            </div>
          </div>
        </div>

        {/* Navigation Links */}
        <div className="mb-8">
          <h2 className="text-xl font-semibold text-white mb-4">Quick Actions</h2>
          <div className="flex flex-wrap gap-4">
            <a
              href={`/access-manager/${selectedChain}`}
              className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
            >
              🔐 Access Manager
            </a>
            <a
              href={`/interest-rates`}
              className="px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-semibold transition-colors"
            >
              📊 Interest Rates
            </a>
          </div>
        </div>

        {/* Fleet Cards Section */}
        <div className="mb-4">
          <h2 className="text-xl font-semibold text-white mb-4">
            Available Fleets ({fleets.length})
          </h2>
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
