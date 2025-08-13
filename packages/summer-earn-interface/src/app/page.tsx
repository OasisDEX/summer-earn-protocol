'use client'

import { useEffect, useState } from 'react'
import { ChainSelector } from '../components/ChainSelector'
import { EnvironmentSelector } from '../components/EnvironmentSelector'
import { FleetCard } from '../components/FleetCard'
import { Skeleton } from '../components/Skeleton'
import { useActiveFleets } from '../hooks/useActiveFleets'
import { useEnvironment } from '../hooks/useEnvironment'
import { useLocalStorage } from '../hooks/useLocalStorage'
import { useSyncWalletChain } from '../hooks/useSyncWalletChain'
import type { ChainId } from '../types'

export default function Home() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '1')
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const { environment, setEnvironment } = useEnvironment()
  useSyncWalletChain(selectedChain)
  useEffect(() => {
    setStoredChain(selectedChain)
  }, [selectedChain, setStoredChain])

  const { fleets, loading, error } = useActiveFleets({
    chainId: selectedChain,
    environment,
  })

  const isLoading = loading

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
    <main className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-white mb-2">Summer Earn Protocol</h1>
          <p className="text-gray-300 mb-6">
            Manage your DeFi positions and protocol roles across multiple chains
          </p>

          <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
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
            <a
              href={`/vesting/8453`}
              className="px-6 py-3 bg-green-600 hover:bg-green-700 text-white rounded-lg font-semibold transition-colors"
            >
              🎁 Vesting (Base)
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
          {isLoading
            ? Array.from({ length: 6 }).map((_, i) => (
                <div
                  key={i}
                  className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur"
                >
                  <Skeleton className="h-6 w-40 mb-4" />
                  <Skeleton className="h-4 w-24 mb-6" />
                  <div className="space-y-4">
                    <Skeleton className="h-16 w-full" />
                    <Skeleton className="h-16 w-full" />
                  </div>
                </div>
              ))
            : fleets.map((fleet) => (
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
