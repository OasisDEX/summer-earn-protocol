'use client'

import { useState } from 'react'

import type { ArkRewardsData, FleetRewardsData } from '../types'
import { Badge } from './ui'

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
    <div className="bg-surface-container-high rounded-xl border border-white/10 shadow-card backdrop-blur">
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full p-6 text-left hover:bg-white/5 transition-colors rounded-xl"
      >
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-xl font-semibold text-on-surface mb-2">{fleet.name}</h3>
            <div className="flex items-center space-x-4 text-sm text-on-surface-variant tabular-nums">
              <span className="flex items-center">
                <span className="w-2 h-2 bg-info rounded-full mr-2"></span>
                {totalTokenBalances} Token Balances
              </span>
              <span className="flex items-center">
                <span className="w-2 h-2 bg-success rounded-full mr-2"></span>
                {totalClaimableRewards} Claimable Rewards
              </span>
            </div>
          </div>
          <div className="text-on-surface-variant">{isExpanded ? '▼' : '▶'}</div>
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

  const actionTone =
    ark.actionType === 'sweepAndStart'
      ? 'info'
      : ark.actionType === 'harvestAndStart'
        ? 'success'
        : 'neutral'

  return (
    <div className="bg-white/5 rounded-lg p-4 border border-white/5">
      <div className="flex items-center justify-between mb-4">
        <h4 className="text-lg font-medium text-on-surface">{ark.name}</h4>
        <Badge tone={actionTone} size="sm">
          {ark.actionType === 'sweepAndStart'
            ? 'Sweep & Start'
            : ark.actionType === 'harvestAndStart'
              ? 'Harvest & Start'
              : 'None'}
        </Badge>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Token Balances */}
        {hasTokenBalances && (
          <div>
            <h5 className="text-sm font-medium text-on-surface-variant mb-3 flex items-center">
              <span className="w-2 h-2 bg-info rounded-full mr-2"></span>
              Token Balances
            </h5>
            <div className="space-y-2">
              {ark.tokenBalances.map((token) => (
                <div
                  key={token.address}
                  className="flex items-center justify-between bg-white/5 rounded-lg p-3"
                >
                  <div>
                    <div className="text-on-surface font-medium">{token.symbol}</div>
                    <div className="text-xs text-on-surface-variant tabular-nums">
                      Threshold: {token.threshold.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-success font-medium tabular-nums">
                      {token.balanceFormatted.toLocaleString(undefined, {
                        maximumFractionDigits: 6,
                      })}
                    </div>
                    <div className="text-xs text-on-surface-variant">
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
            <h5 className="text-sm font-medium text-on-surface-variant mb-3 flex items-center">
              <span className="w-2 h-2 bg-success rounded-full mr-2"></span>
              Claimable Rewards
            </h5>
            <div className="space-y-2">
              {ark.claimableRewards.map((reward, index) => (
                <div
                  key={`${reward.contractAddress}-${index}`}
                  className="flex items-center justify-between bg-white/5 rounded-lg p-3"
                >
                  <div>
                    <div className="text-on-surface font-medium">{reward.symbol}</div>
                    <div className="text-xs text-on-surface-variant tabular-nums">
                      Threshold: {reward.threshold.toLocaleString()}
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="text-success font-medium tabular-nums">
                      {reward.amountFormatted.toLocaleString(undefined, {
                        maximumFractionDigits: 6,
                      })}
                    </div>
                    <div className="text-xs text-on-surface-variant">
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
