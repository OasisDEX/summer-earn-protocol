'use client'

import { useState } from 'react'

import { ChainSelector } from '../../components/ChainSelector'
import { FleetRewards } from '../../components/FleetRewards'
import { Skeleton } from '../../components/Skeleton'
import { Button, EmptyState, ErrorState, PageHeader } from '../../components/ui'
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
      <div className="min-h-screen p-8">
        <div className="max-w-7xl mx-auto">
          <ErrorState
            title="Error loading rewards data"
            error={error}
            action={
              <Button variant="danger" onClick={() => refetch()}>
                Retry
              </Button>
            }
          />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen p-8">
      <div className="max-w-7xl mx-auto">
        {/* Header Section */}
        <div className="mb-8">
          <PageHeader
            title="Rewards Dashboard"
            description="View harvestable rewards and token balances across all fleets and ARKs"
            actions={
              <Button variant="primary" onClick={() => refetch()} disabled={isLoading}>
                <span>{isLoading ? '⟳' : '↻'}</span>
                <span>{isLoading ? 'Refreshing…' : 'Refresh'}</span>
              </Button>
            }
          />

          <div className="bg-surface-container-high p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-lg font-semibold text-on-surface mb-2">Network Selection</h2>
                <p className="text-on-surface-variant text-sm">
                  Select a network to view rewards data
                </p>
              </div>
              <ChainSelector selectedChain={selectedChain} onChange={handleChainChange} />
            </div>
          </div>
        </div>

        {/* Stats Overview */}
        {rewardsData && (
          <div className="mb-8">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-surface-container-high p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-primary/15 rounded-lg">
                    <span className="text-2xl">🏴‍☠️</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-on-surface tabular-nums">
                      {rewardsData.fleets.length}
                    </div>
                    <div className="text-on-surface-variant">Active Fleets</div>
                  </div>
                </div>
              </div>

              <div className="bg-surface-container-high p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-success/15 rounded-lg">
                    <span className="text-2xl">⚓</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-on-surface tabular-nums">
                      {rewardsData.fleets.reduce((sum, fleet) => sum + fleet.arks.length, 0)}
                    </div>
                    <div className="text-on-surface-variant">Total ARKs</div>
                  </div>
                </div>
              </div>

              <div className="bg-surface-container-high p-6 rounded-xl border border-white/10 shadow-card backdrop-blur">
                <div className="flex items-center">
                  <div className="p-3 bg-violet-400/15 rounded-lg">
                    <span className="text-2xl">💰</span>
                  </div>
                  <div className="ml-4">
                    <div className="text-2xl font-bold text-on-surface tabular-nums">
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
                    <div className="text-on-surface-variant">Total Rewards</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Fleet Rewards */}
        <div className="mb-4">
          <h2 className="text-xl font-semibold text-on-surface mb-4">
            Fleet Rewards - {rewardsData?.chainName || 'Loading…'}
          </h2>
        </div>

        {isLoading ? (
          <div className="space-y-6">
            {Array.from({ length: 3 }).map((_, i) => (
              <div
                key={i}
                className="bg-surface-container-high p-6 rounded-xl border border-white/10 shadow-card backdrop-blur"
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
          <EmptyState
            title="No rewards data found"
            description="No fleets with harvestable rewards or token balances found on this network"
          />
        ) : (
          <div className="space-y-6">
            {rewardsData?.fleets.map((fleet) => <FleetRewards key={fleet.address} fleet={fleet} />)}
          </div>
        )}

        {/* Footer Info */}
        <div className="mt-12 text-center">
          <div className="text-on-surface-variant text-sm">
            Data refreshes automatically every 30 seconds. Last updated:{' '}
            {new Date().toLocaleTimeString()}
          </div>
        </div>
      </div>
    </div>
  )
}
