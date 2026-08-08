'use client'

import React from 'react'
import { Address, formatUnits } from 'viem'
import { useBalance } from 'wagmi'

import { CHAINS } from '@/config/chains'
import deploymentConfigRaw from '@/config/index.json'
import { DeploymentConfig } from '@/types/deployment'
import { SimulationResult } from '@/types/tenderly'

const deploymentConfig = deploymentConfigRaw as DeploymentConfig

interface SimCardProps {
  chain: (typeof CHAINS)[0]
  result?: SimulationResult
  isTargeted: boolean
}

export function SimCard({ chain, result, isTargeted }: SimCardProps) {
  const isUnsupported = !chain.tenderlyId

  const timelockAddress = deploymentConfig[chain.key]?.deployedContracts?.govV2?.timelock
    ?.address as Address | undefined
  const { data: liveBalance } = useBalance({
    address: timelockAddress,
    chainId: Number(chain.id),
    query: {
      enabled: !!timelockAddress && !result?.balance,
    },
  })

  const displayBalance =
    result?.balance ||
    (liveBalance ? formatUnits(liveBalance.value, liveBalance.decimals) : undefined)

  return (
    <div
      className={`border rounded-xl bg-surface2 p-3.5 transition-all ${
        isTargeted ? 'border-line2 opacity-100' : 'border-line opacity-50'
      }`}
    >
      <div className="flex items-center gap-2.5">
        <div className="w-[30px] h-[30px] rounded-lg flex items-center justify-center font-bold text-xs bg-pink-bg text-brand-pink flex-shrink-0">
          {chain.name.charAt(0)}
        </div>
        <div className="min-w-0 flex-1">
          <span className="block text-xs font-semibold text-fg">{chain.name}</span>
          {displayBalance !== undefined && (
            <span className="block font-mono text-[10px] font-semibold text-brand-pink">
              {parseFloat(displayBalance).toFixed(4)} ETH
            </span>
          )}
        </div>
        {isTargeted && !isUnsupported && result?.status === 'success' && (
          <span className="text-ok text-xs font-bold">✓</span>
        )}
      </div>

      {isUnsupported && (
        <div className="mt-3 p-2 rounded-lg border border-line bg-tint text-[10px] font-semibold tracking-wider text-fg3 text-center uppercase leading-tight">
          Simulation
          <br />
          not available
        </div>
      )}

      {!isTargeted && !isUnsupported && (
        <div className="mt-3 text-[10px] font-semibold tracking-wider uppercase text-fg3 text-center py-1">
          Idle
        </div>
      )}

      {isTargeted && !isUnsupported && !result && (
        <div className="mt-3 text-[10px] font-semibold tracking-wider uppercase text-fg3 text-center py-1">
          Not run yet
        </div>
      )}

      {isTargeted &&
        !isUnsupported &&
        result &&
        (result.status === 'success' || result.status === 'fail' || result.status === 'error') && (
          <div className="mt-3">
            {result.status === 'success' && result.gasUsed !== undefined && (
              <div className="flex justify-between items-baseline text-[10px] font-semibold tracking-wider uppercase text-fg3">
                <span>Gas used</span>
                <span className="font-mono text-xs text-fg tracking-normal uppercase-none">
                  {result.gasUsed.toLocaleString()}
                </span>
              </div>
            )}

            {(result.status === 'fail' || result.status === 'error') && (
              <div className="p-2 rounded-lg bg-crit-bg border border-crit/20 text-crit text-[10px] font-semibold line-clamp-2">
                {result.error || 'Execution Reverted'}
              </div>
            )}

            {(result.simulationId || result.shareUrl) && (
              <a
                href={
                  result.shareUrl ||
                  `https://dashboard.tenderly.co/oazoapps/lazy-summer-governance-dashboard/simulator/${result.simulationId}`
                }
                target="_blank"
                rel="noreferrer"
                className="block w-full mt-2.5 h-[32px] rounded-lg border border-line2 bg-surface3 text-brand-pink text-[10px] font-bold tracking-wider uppercase flex items-center justify-center hover:bg-surface2 transition-colors"
              >
                Execution trace
              </a>
            )}
          </div>
        )}
    </div>
  )
}
