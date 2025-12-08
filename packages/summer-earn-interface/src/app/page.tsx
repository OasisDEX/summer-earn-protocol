'use client'

import { useEffect, useState } from 'react'
import Link from 'next/link'

import { ChainSelector } from '../components/ChainSelector'
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
  const { environment } = useEnvironment()
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
      <div className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10">
        <div className="max-w-6xl mx-auto">
          <div className="text-center text-red-400 bg-red-900/20 p-6 rounded-3xl border border-red-500/50 backdrop-blur-md">
            Error loading fleets: {error.message}
          </div>
        </div>
      </div>
    )
  }

  return (
    <main className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10 text-gray-100 font-sans">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header Section */}
        <div className="space-y-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-4xl md:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-600">
                  Summer Earn Protocol
                </h1>
                <span className="px-3 py-1 rounded-full border border-blue-500/30 bg-blue-900/20 text-xs uppercase tracking-wide text-blue-300 font-semibold h-fit">
                  {environment}
                </span>
              </div>
              <p className="text-gray-400 text-lg">
                Manage your DeFi positions and protocol roles across multiple chains
              </p>
            </div>
          </div>

          <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <ChainSelector selectedChain={selectedChain} onChange={setSelectedChain} />
            </div>
          </div>
        </div>

        {/* Navigation Links */}
        <div className="space-y-4">
          <h2 className="text-2xl font-bold text-white">Quick Actions</h2>
          <div className="flex flex-wrap gap-4">
            <Link
              href={`/access-manager/${selectedChain}`}
              className="px-6 py-4 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              🔐 Access Manager
            </Link>
            <Link
              href={`/interest-rates`}
              className="px-6 py-4 bg-purple-600 hover:bg-purple-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              📊 Interest Rates
            </Link>
            <Link
              href={`/institutions`}
              className="px-6 py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              🏦 Institutions
            </Link>
            <Link
              href={`/vesting/8453`}
              className="px-6 py-4 bg-green-600 hover:bg-green-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              🎁 Vesting (Base)
            </Link>
            <Link
              href="/intent-system"
              className="px-6 py-4 bg-cyan-600 hover:bg-cyan-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              ⚡ Intent System
            </Link>
            <Link
              href="/rewards"
              className="px-6 py-4 bg-orange-600 hover:bg-orange-700 text-white rounded-xl font-bold transition-all shadow-lg hover:-translate-y-0.5"
            >
              💰 Rewards Dashboard
            </Link>
          </div>
        </div>

        {/* Fleet Cards Section */}
        <div className="space-y-6">
          <h2 className="text-2xl font-bold text-white">Available Fleets ({fleets.length})</h2>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {isLoading
              ? Array.from({ length: 6 }).map((_, i) => (
                  <div
                    key={i}
                    className="bg-charcoal-900/70 p-7 rounded-3xl border border-white/10 shadow-2xl backdrop-blur-md"
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
                  <div
                    key={fleet.address}
                    className="transition-transform hover:-translate-y-1 duration-300"
                  >
                    <FleetCard
                      fleetInfo={fleet}
                      userInfo={null}
                      assetDecimals={fleet.assetDecimals}
                      assetSymbol={fleet.assetSymbol}
                      chainId={selectedChain}
                    />
                  </div>
                ))}
          </div>
        </div>
      </div>
    </main>
  )
}
