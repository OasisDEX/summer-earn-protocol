'use client'

import { useState } from 'react'

import type { ArkRewardsData, FleetRewardsData } from '../types'

interface FleetRewardsProps {
  fleet: FleetRewardsData
}

export function FleetRewards({ fleet }: FleetRewardsProps) {
  const [isExpanded, setIsExpanded] = useState(false)

  const totalTokenBalances = fleet.arks.reduce((sum, ark) => sum + ark.tokenBalances.length, 0)
  const totalClaimableRewards = fleet.arks.reduce(
    (sum, ark) => sum + ark.claimableRewards.length,
    0,
  )
  const hasAnyRewards = totalTokenBalances > 0 || totalClaimableRewards > 0

  if (!hasAnyRewards) {
    return null
  }

  return (
    <div className="bg-charcoal-800/70 rounded-xl border border-white/10 shadow-card backdrop-blur">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full p-6 text-left hover:bg-charcoal-700/50 transition-colors rounded-xl"
      >
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold text-white mb-2">{fleet.name}</h3>
            <div className="flex items-center space-x-4 text-sm text-gray-300">
              <span className="flex items-center">
                <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
                {totalTokenBalances} Token Balances
              </span>
              <span className="flex items-center">
                <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
                {totalClaimableRewards} Claimable Rewards
              </span>
            </div>
          </div>
          <div className="text-gray-400">{isExpanded ? '▼' : '▶'}</div>
        </div>
      </button>

      {isExpanded && (
        <div className="px-6 pb-6 space-y-4">
          {fleet.arks.map((ark) => (
            <ArkRewards key={ark.address} ark={ark} />
          ))}
        </div>
      )}
    </div>
  )
}

function ArkRewards({ ark }: { ark: ArkRewardsData }) {
  const hasTokenBalances = ark.tokenBalances.length > 0
  const hasClaimableRewards = ark.claimableRewards.length > 0

  if (!hasTokenBalances && !hasClaimableRewards) {
    return null
  }

  return (
    <div className="bg-charcoal-700/50 rounded-lg p-4 border border-white/5">
      <div className="flex items-center justify-between mb-4">
        <h4 className="text-lg font-medium text-white">{ark.name}</h4>
        <span
          className={`px-2 py-1 rounded-full text-xs font-medium ${
            ark.actionType === 'sweepAndStart'
              ? 'bg-blue-500/20 text-blue-400'
              : ark.actionType === 'harvestAndStart'
                ? 'bg-green-500/20 text-green-400'
                : 'bg-gray-500/20 text-gray-400'
          }`}
        >
          {ark.actionType === 'sweepAndStart'
            ? 'Sweep & Start'
            : ark.actionType === 'harvestAndStart'
              ? 'Harvest & Start'
              : 'None'}
        </span>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Token Balances */}
        {hasTokenBalances && (
          <div>
            <h5 className="text-sm font-medium text-gray-300 mb-3 flex items-center">
              <span className="w-2 h-2 bg-blue-400 rounded-full mr-2"></span>
              Token Balances
            </h5>
            <div className="space-y-2">
              {ark.tokenBalances.map((token) => (
                <div
                  key={token.address}
                  className="flex items-center justify-between bg-charcoal-600/50 rounded-lg p-3"
                >
                  <div>
                    <div className="text-white font-medium">{token.symbol}</div>
                    <div className="text-xs text-gray-400">
                      Threshold: {token.threshold.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-green-400 font-medium">
                      {token.balanceFormatted.toLocaleString(undefined, {
                        maximumFractionDigits: 6,
                      })}
                    </div>
                    <div className="text-xs text-gray-400">
                      {token.balanceFormatted > token.threshold
                        ? '✓ Above threshold'
                        : 'Below threshold'}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Claimable Rewards */}
        {hasClaimableRewards && (
          <div>
            <h5 className="text-sm font-medium text-gray-300 mb-3 flex items-center">
              <span className="w-2 h-2 bg-green-400 rounded-full mr-2"></span>
              Claimable Rewards
            </h5>
            <div className="space-y-2">
              {ark.claimableRewards.map((reward, index) => (
                <div
                  key={`${reward.contractAddress}-${index}`}
                  className="flex items-center justify-between bg-charcoal-600/50 rounded-lg p-3"
                >
                  <div>
                    <div className="text-white font-medium">{reward.symbol}</div>
                    <div className="text-xs text-gray-400">
                      Threshold: {reward.threshold.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-green-400 font-medium">
                      {reward.amountFormatted.toLocaleString(undefined, {
                        maximumFractionDigits: 6,
                      })}
                    </div>
                    <div className="text-xs text-gray-400">
                      {reward.amountFormatted > reward.threshold
                        ? '✓ Above threshold'
                        : 'Below threshold'}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
