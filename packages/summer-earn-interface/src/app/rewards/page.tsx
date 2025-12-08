'use client'

import { useState } from 'react'

import { ChainSelector } from '../../components/ChainSelector'
import { FleetRewards } from '../../components/FleetRewards'
import { Skeleton } from '../../components/Skeleton'
import { useEnvironment } from '../../hooks/useEnvironment'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useRewardsData } from '../../hooks/useRewardsData'
import type { ChainId } from '../../types'

export default function RewardsPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '1')
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)
  const { environment } = useEnvironment()

  const { data: rewardsData, isLoading, error, refetch } = useRewardsData(selectedChain)

  const handleChainChange = (newChain: ChainId) => {
    setSelectedChain(newChain)
    setStoredChain(newChain)
  }

  if (error) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10">
        <div className="max-w-6xl mx-auto">
          <div className="text-center">
            <div className="text-red-400 text-lg mb-4">Error loading rewards data</div>
            <div className="text-gray-400 mb-6">{error.message}</div>
            <button
              onClick={() => refetch()}
              className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-xl font-semibold transition-colors shadow-lg"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-black via-charcoal-900 to-black p-6 md:p-10 text-gray-100 font-sans">
      <div className="max-w-6xl mx-auto space-y-8">
        {/* Header Section */}
        <div className="space-y-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-4xl md:text-5xl font-extrabold text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-600">
                  Rewards Dashboard
                </h1>
                <span className="px-3 py-1 rounded-full border border-blue-500/30 bg-blue-900/20 text-xs uppercase tracking-wide text-blue-300 font-semibold h-fit">
                  {environment}
                </span>
              </div>
              <p className="text-gray-400">
                View harvestable rewards and token balances across all fleets and ARKs
              </p>
            </div>
            <button
              onClick={() => refetch()}
              disabled={isLoading}
              className="px-5 py-2.5 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-700 text-white rounded-xl font-medium transition-colors flex items-center space-x-2 shadow-lg"
            >
              <span>{isLoading ? '⟳' : '↻'}</span>
              <span>{isLoading ? 'Refreshing...' : 'Refresh'}</span>
            </button>
          </div>

          <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-bold text-white mb-2">Network Selection</h2>
                <p className="text-gray-300 text-sm">Select a network to view rewards data</p>
              </div>
              <ChainSelector selectedChain={selectedChain} onChange={handleChainChange} />
            </div>
          </div>
        </div>

        {/* Stats Overview */}
        {rewardsData && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
              <div className="flex items-center">
                <div className="p-3 bg-blue-500/20 rounded-xl border border-blue-500/30">
                  <span className="text-2xl">🏴‍☠️</span>
                </div>
                <div className="ml-4">
                  <div className="text-3xl font-bold text-white">{rewardsData.fleets.length}</div>
                  <div className="text-gray-400">Active Fleets</div>
                </div>
              </div>
            </div>

            <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
              <div className="flex items-center">
                <div className="p-3 bg-emerald-500/20 rounded-xl border border-emerald-500/30">
                  <span className="text-2xl">⚓</span>
                </div>
                <div className="ml-4">
                  <div className="text-3xl font-bold text-white">
                    {rewardsData.fleets.reduce((sum, fleet) => sum + fleet.arks.length, 0)}
                  </div>
                  <div className="text-gray-400">Total ARKs</div>
                </div>
              </div>
            </div>

            <div className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md">
              <div className="flex items-center">
                <div className="p-3 bg-purple-500/20 rounded-xl border border-purple-500/30">
                  <span className="text-2xl">💰</span>
                </div>
                <div className="ml-4">
                  <div className="text-3xl font-bold text-white">
                    {rewardsData.fleets.reduce(
                      (sum, fleet) =>
                        sum +
                        fleet.arks.reduce(
                          (arkSum, ark) =>
                            arkSum + ark.tokenBalances.length + ark.claimableRewards.length,
                          0,
                        ),
                      0,
                    )}
                  </div>
                  <div className="text-gray-400">Total Rewards</div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Fleet Rewards */}
        <div>
          <h2 className="text-2xl font-bold text-white mb-6">
            Fleet Rewards - {rewardsData?.chainName || 'Loading...'}
          </h2>

          {isLoading ? (
            <div className="space-y-6">
              {Array.from({ length: 3 }).map((_, i) => (
                <div
                  key={i}
                  className="rounded-3xl p-7 bg-charcoal-900/70 border border-white/10 shadow-2xl backdrop-blur-md"
                >
                  <Skeleton className="h-6 w-40 mb-4" />
                  <Skeleton className="h-4 w-24 mb-6" />
                  <div className="space-y-4">
                    <Skeleton className="h-16 w-full" />
                    <Skeleton className="h-16 w-full" />
                  </div>
                </div>
              ))}
            </div>
          ) : rewardsData?.fleets.length === 0 ? (
            <div className="text-center py-12 rounded-3xl bg-charcoal-900/50 border border-white/5">
              <div className="text-gray-300 text-lg mb-4">No rewards data found</div>
              <div className="text-gray-500 text-sm">
                No fleets with harvestable rewards or token balances found on this network
              </div>
            </div>
          ) : (
            <div className="space-y-6">
              {rewardsData?.fleets.map((fleet) => (
                <FleetRewards key={fleet.address} fleet={fleet} />
              ))}
            </div>
          )}
        </div>

        {/* Footer Info */}
        <div className="mt-12 text-center pb-8">
          <div className="text-gray-500 text-sm">
            Data refreshes automatically every 30 seconds. Last updated:{' '}
            {new Date().toLocaleTimeString()}
          </div>
        </div>
      </div>
    </div>
  )
}
