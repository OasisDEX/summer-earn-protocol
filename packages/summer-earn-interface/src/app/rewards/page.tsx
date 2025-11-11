'use client'

import { useState } from 'react'

import { ChainSelector } from '../../components/ChainSelector'
import { FleetRewards } from '../../components/FleetRewards'
import { Skeleton } from '../../components/Skeleton'
import { useLocalStorage } from '../../hooks/useLocalStorage'
import { useRewardsData } from '../../hooks/useRewardsData'
import type { ChainId } from '../../types'

export default function RewardsPage() {
  const [storedChain, setStoredChain] = useLocalStorage<ChainId>('selectedChain', '1')
  const [selectedChain, setSelectedChain] = useState<ChainId>(storedChain)

  const { data: rewardsData, isLoading, error, refetch } = useRewardsData(selectedChain)

  const handleChainChange = (newChain: ChainId) => {
    setSelectedChain(newChain)
    setStoredChain(newChain)
  }

  if (error) {
    return (
      <div className="min-h-screen bg-charcoal-900 p-8">
        <div className="max-w-7xl mx-auto">
          <div className="text-center">
            <div className="text-red-400 text-lg mb-4">Error loading rewards data</div>
            <div className="text-gray-400 mb-6">{error.message}</div>
            <button
              onClick={() => refetch()}
              className="px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg font-semibold transition-colors"
            >
              Retry
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-charcoal-900 p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-6">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">Rewards Dashboard</h1>
              <p className="text-gray-300">
                View harvestable rewards and token balances across all fleets and ARKs
              </p>
            </div>
            <button
              onClick={() => refetch()}
              disabled={isLoading}
              className="px-4 py-2 bg-blue-600 hover:bg-blue-700 disabled:bg-gray-600 text-white rounded-lg font-medium transition-colors flex items-center space-x-2"
            >
              <span>{isLoading ? '⟳' : '↻'}</span>
              <span>{isLoading ? 'Refreshing...' : 'Refresh'}</span>
            </button>
          </div>

          <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-white mb-2">Network Selection</h2>
                <p className="text-gray-300 text-sm">Select a network to view rewards data</p>
              </div>
              <ChainSelector selectedChain={selectedChain} onChange={handleChainChange} />
            </div>
          </div>
        </div>

        {/* Stats Overview */}
        {rewardsData && (
          <div className="mb-8">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-blue-500/20 rounded-lg">
                    <span className="text-2xl">🏴‍☠️</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-white">{rewardsData.fleets.length}</div>
                    <div className="text-gray-300">Active Fleets</div>
                  </div>
                </div>
              </div>

              <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-green-500/20 rounded-lg">
                    <span className="text-2xl">⚓</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-white">
                      {rewardsData.fleets.reduce((sum, fleet) => sum + fleet.arks.length, 0)}
                    </div>
                    <div className="text-gray-300">Total ARKs</div>
                  </div>
                </div>
              </div>

              <div className="bg-charcoal-800/70 p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-purple-500/20 rounded-lg">
                    <span className="text-2xl">💰</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-white">
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
                    <div className="text-gray-300">Total Rewards</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Fleet Rewards */}
        <div className="mb-4">
          <h2 className="text-xl font-semibold text-white mb-4">
            Fleet Rewards - {rewardsData?.chainName || 'Loading...'}
          </h2>
        </div>

        {isLoading ? (
          <div className="space-y-6">
            {Array.from({ length: 3 }).map((_, i) => (
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
            ))}
          </div>
        ) : rewardsData?.fleets.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-gray-400 text-lg mb-4">No rewards data found</div>
            <div className="text-gray-500 text-sm">
              No fleets with harvestable rewards or token balances found on this network
            </div>
          </div>
        ) : (
          <div className="space-y-6">
            {rewardsData?.fleets.map((fleet) => <FleetRewards key={fleet.address} fleet={fleet} />)}
          </div>
        )}

        {/* Footer Info */}
        <div className="mt-12 text-center">
          <div className="text-gray-400 text-sm">
            Data refreshes automatically every 30 seconds. Last updated:{' '}
            {new Date().toLocaleTimeString()}
          </div>
        </div>
      </div>
    </div>
  )
}
