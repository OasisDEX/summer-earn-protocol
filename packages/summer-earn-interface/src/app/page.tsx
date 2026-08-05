'use client'

export const dynamic = 'force-dynamic'

import { Suspense, useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'next/navigation'

import { ChainPills } from '../components/ChainPills'
import { FleetCard } from '../components/FleetCard'
import { Skeleton } from '../components/Skeleton'
import { StatCard } from '../components/StatCard'
import { ErrorState } from '../components/ui'
import { useActiveFleets } from '../hooks/useActiveFleets'
import { useEnvironment } from '../hooks/useEnvironment'
import { useLocalStorage } from '../hooks/useLocalStorage'
import { useSyncWalletChain } from '../hooks/useSyncWalletChain'
import type { ChainId } from '../types'
import { formatLargeNumber } from '../utils/decimals'

const VALID_CHAINS: ChainId[] = ['1', '42161', '8453', '146', '11155111']

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

  // TVL per asset — different assets (USDC vs WETH) cannot be summed without a
  // price feed, so the dominant asset leads and the rest go in the hint line.
  const totalTVL = useMemo(() => {
    if (fleets.length === 0) return { value: '0', hint: undefined }
    const byAsset = new Map<string, { total: bigint; decimals: number; count: number }>()
    for (const f of fleets) {
      const entry = byAsset.get(f.assetSymbol)
      if (entry) {
        entry.total += f.totalAssets
        entry.count += 1
      } else {
        byAsset.set(f.assetSymbol, { total: f.totalAssets, decimals: f.assetDecimals, count: 1 })
      }
    }
    const labels = [...byAsset.entries()]
      .map(([symbol, { total, decimals, count }]) => ({
        label: `${formatLargeNumber(total, decimals)} ${symbol}`,
        count,
        symbol,
      }))
      .sort((a, b) => b.count - a.count || a.symbol.localeCompare(b.symbol))
    return {
      value: labels[0].label,
      hint:
        labels.length > 1
          ? `+ ${labels
              .slice(1)
              .map((l) => l.label)
              .join(' · ')}`
          : undefined,
    }
  }, [fleets])

  const isLoading = loading

  if (error) {
    return <ErrorState title="Fleets unavailable" error={error} />
  }

  return (
    <div>
      {/* Control Bar */}
      <section className="mb-10 flex flex-col md:flex-row md:items-center justify-between gap-6">
        <ChainPills selectedChain={selectedChain} onChange={setSelectedChain} />
        <div className="relative w-full md:w-80">
          <svg
            aria-hidden="true"
            className="absolute left-4 top-1/2 -translate-y-1/2 text-on-surface-variant"
            width="16"
            height="16"
            viewBox="0 0 16 16"
            fill="none"
          >
            <circle cx="7" cy="7" r="4.5" stroke="currentColor" strokeWidth="1.5" />
            <path
              d="M10.5 10.5L14 14"
              stroke="currentColor"
              strokeWidth="1.5"
              strokeLinecap="round"
            />
          </svg>
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search fleets or assets..."
            className="w-full bg-white/5 border border-white/10 rounded-xl py-3 pl-12 pr-4 text-sm focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all text-on-surface placeholder:text-on-surface-variant/60"
          />
        </div>
      </section>

      {/* Stats Overview */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <StatCard
          label="Total Value Locked"
          value={isLoading ? '…' : totalTVL.value}
          hint={isLoading ? undefined : totalTVL.hint}
        />
        <StatCard label="Active Fleets" value={isLoading ? '…' : String(fleets.length)} />
        <StatCard label="24h Volume" value="—" hint="Not tracked" />
        <StatCard label="Average APY" value="—" hint="Not tracked" highlight />
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
          <div className="w-16 h-16 rounded-full bg-white/5 flex items-center justify-center mb-4 group-hover:scale-110 transition-transform text-3xl text-on-surface-variant group-hover:text-primary">
            +
          </div>
          <h4 className="text-on-surface font-bold mb-1">Create New Ark</h4>
          <p className="text-xs text-on-surface-variant max-w-[200px]">
            Launch a custom yield strategy or fleet with your assets.
          </p>
        </a>
      </div>

      {/* Protocol Modules Links */}
      <section className="mt-16">
        <h2 className="text-xl font-headline font-bold text-on-surface mb-6">
          Protocol Modules & Tools
        </h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {[
            { name: 'Access Manager', href: '/access-manager/1' },
            { name: 'Institutions', href: '/institutions' },
            { name: 'Intent System', href: '/intent-system' },
            { name: 'Interest Rates', href: '/interest-rates' },
            { name: 'Rewards', href: '/rewards' },
            { name: 'Roles', href: '/roles/1' },
            { name: 'Rounds Vault', href: '/rounds-vault/1' },
            { name: 'Summer Staking', href: '/summer-staking/8453' },
            { name: 'Vault APR', href: '/vault-apr' },
            { name: 'Vesting', href: '/vesting/8453' },
            { name: 'Vesting Staking', href: '/vesting-staking/8453' },
          ].map((link) => (
            <a
              key={link.href}
              href={link.href}
              className="glass rounded-xl p-4 flex items-center justify-between group hover:bg-white/5 transition-colors border-white/5 hover:border-white/20"
            >
              <span className="text-on-surface font-medium text-sm group-hover:text-primary transition-colors">
                {link.name}
              </span>
              <span className="text-on-surface-variant group-hover:text-primary group-hover:translate-x-1 transition-all">
                →
              </span>
            </a>
          ))}
        </div>
      </section>
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
