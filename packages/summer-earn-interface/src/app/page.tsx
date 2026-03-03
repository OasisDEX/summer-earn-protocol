'use client'

import { Suspense, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'next/navigation'

import { ChainPills } from '../components/ChainPills'
import { FleetCard } from '../components/FleetCard'
import { Skeleton } from '../components/Skeleton'
import { StatCard } from '../components/StatCard'
import { useActiveFleets } from '../hooks/useActiveFleets'
import { useEnvironment } from '../hooks/useEnvironment'
import { useLocalStorage } from '../hooks/useLocalStorage'
import { useSyncWalletChain } from '../hooks/useSyncWalletChain'
import type { ChainId } from '../types'
import { formatDecimalOutput } from '../utils/decimals'

const VALID_CHAINS: ChainId[] = ['1', '42161', '8453', '146']

function HomeContent() {
  const searchParams = useSearchParams()
  const chainFromUrl = searchParams.get('chain')
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '1')
  const initialChain: ChainId =
    chainFromUrl && VALID_CHAINS.includes(chainFromUrl as ChainId)
      ? (chainFromUrl as ChainId)
      : storedChain
  const [selectedChain, setSelectedChain] = useState<ChainId>(initialChain)
  const [searchQuery, setSearchQuery] = useState('')
  const { environment } = useEnvironment()
  useSyncWalletChain(selectedChain)
  useEffect(() => {
    setStoredChain(selectedChain)
  }, [selectedChain, setStoredChain])

  useEffect(() => {
    if (chainFromUrl && VALID_CHAINS.includes(chainFromUrl as ChainId)) {
      setSelectedChain(chainFromUrl as ChainId)
    }
  }, [chainFromUrl])

  const { fleets, loading, error } = useActiveFleets({
    chainId: selectedChain,
    environment,
  })

  const filteredFleets = useMemo(() => {
    if (!searchQuery.trim()) return fleets
    const q = searchQuery.toLowerCase()
    return fleets.filter(
      (f) =>
        f.name.toLowerCase().includes(q) ||
        f.symbol.toLowerCase().includes(q) ||
        f.assetSymbol.toLowerCase().includes(q),
    )
  }, [fleets, searchQuery])

  const totalTVL = useMemo(() => {
    if (fleets.length === 0) return '0'
    const primaryDecimals = fleets[0]?.assetDecimals ?? 18
    const primarySymbol = fleets[0]?.assetSymbol ?? ''
    const sum = fleets.reduce((acc, f) => acc + f.totalAssets, BigInt(0))
    return `${formatDecimalOutput(sum, primaryDecimals)} ${primarySymbol}`
  }, [fleets])

  const isLoading = loading

  if (error) {
    return (
      <div className="min-h-screen bg-charcoal-900 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center text-red-400">Error loading fleets: {error.message}</div>
        </div>
      </div>
    )
  }

  return (
    <div className="max-w-7xl mx-auto px-6 py-8">
      {/* Control Bar */}
      <section className="mb-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
        <ChainPills selectedChain={selectedChain} onChange={setSelectedChain} />
        <div className="relative min-w-[300px]">
          <span className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 text-lg">
            🔍
          </span>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search fleets or assets..."
            className="w-full bg-white/5 border border-white/10 rounded-xl py-3 pl-12 pr-4 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all text-white placeholder-slate-500"
          />
        </div>
      </section>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard label="Total Value Locked" value={isLoading ? '…' : totalTVL} />
        <StatCard label="Active Fleets" value={isLoading ? '…' : String(fleets.length)} />
        <StatCard label="24h Volume" value="—" suffix="(N/A)" />
        <StatCard label="Average APY" value="—" highlight />
      </div>

      {/* Fleet Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading
          ? Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="glass rounded-xl p-6">
                <Skeleton className="h-6 w-40 mb-4" />
                <Skeleton className="h-4 w-24 mb-6" />
                <div className="space-y-4">
                  <Skeleton className="h-16 w-full" />
                  <Skeleton className="h-16 w-full" />
                </div>
              </div>
            ))
          : filteredFleets.map((fleet) => (
              <FleetCard
                key={fleet.address}
                fleetInfo={fleet}
                userInfo={null}
                assetDecimals={fleet.assetDecimals}
                assetSymbol={fleet.assetSymbol}
                chainId={selectedChain}
              />
            ))}
        {/* Create New Ark Teaser */}
        <a
          href="/access-manager/1"
          className="glass rounded-xl p-6 border-dashed border-2 border-white/10 flex flex-col items-center justify-center text-center group cursor-pointer hover:border-primary/40 transition-all min-h-[280px]"
        >
          <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform text-3xl text-slate-500 group-hover:text-primary">
            +
          </div>
          <h4 className="text-white font-bold mb-1">Create New Ark</h4>
          <p className="text-xs text-slate-500 max-w-[200px]">
            Launch a custom yield strategy or fleet with your assets.
          </p>
        </a>
      </div>
    </div>
  )
}

export default function Home() {
  return (
    <Suspense
      fallback={
        <div className="min-h-[400px] flex items-center justify-center">
          <div className="glass rounded-xl p-8 animate-pulse">
            <div className="h-6 w-48 bg-white/10 rounded mb-4" />
            <div className="h-4 w-32 bg-white/10 rounded" />
          </div>
        </div>
      }
    >
      <HomeContent />
    </Suspense>
  )
}
