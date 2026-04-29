'use client'

import React from 'react'
import { AlertCircle, CheckCircle2, Loader2 } from 'lucide-react'
import { Address, formatUnits } from 'viem'
import { useBalance } from 'wagmi'

import { CHAINS, HUB_CHAIN_ID } from '@/config/chains'
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
  const chainColor = chain.id === HUB_CHAIN_ID ? '#7dd3fc' : '#c8a0f0'
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
      className={`p-6 rounded-2xl border bg-surface-container-lowest transition-all duration-300 ${isTargeted ? 'border-outline-variant shadow-lg' : 'opacity-40 border-transparent shadow-none'}`}
    >
      <div className="flex justify-between items-center mb-4">
        <div className="flex items-center gap-3">
          <div
            className="w-8 h-8 rounded-lg flex items-center justify-center border text-xs font-black"
            style={{
              backgroundColor: `${chainColor}20`,
              borderColor: `${chainColor}40`,
              color: chainColor,
            }}
          >
            {chain.name.charAt(0)}
          </div>
          <div className="flex flex-col">
            <span className="font-bold text-sm leading-tight">{chain.name}</span>
            {displayBalance !== undefined && (
              <span className="text-[10px] text-primary font-bold font-mono">
                {parseFloat(displayBalance).toFixed(4)} ETH
              </span>
            )}
          </div>
        </div>
        {isTargeted && !isUnsupported && (
          <div className="flex items-center">
            {result?.status === 'loading' && (
              <Loader2 className="animate-spin text-primary" size={14} />
            )}
            {result?.status === 'success' && <CheckCircle2 className="text-success" size={14} />}
            {result?.status === 'fail' && <AlertCircle className="text-error" size={14} />}
            {result?.status === 'error' && (
              <AlertCircle className="text-error opacity-50" size={14} />
            )}
          </div>
        )}
      </div>

      {isUnsupported && (
        <div className="p-3 rounded-xl bg-on-surface/5 border border-outline-variant/30">
          <p className="text-[10px] text-on-surface-variant font-bold text-center uppercase tracking-widest leading-relaxed">
            Simulation
            <br />
            Not Available
          </p>
        </div>
      )}

      {isTargeted &&
        !isUnsupported &&
        (result?.status === 'success' ||
          result?.status === 'fail' ||
          result?.status === 'error') && (
          <div className="space-y-3 animate-in fade-in duration-500">
            {result.status === 'success' && result.gasUsed !== undefined && (
              <div className="flex justify-between text-[10px] font-medium text-on-surface-variant uppercase tracking-wider">
                <span>Gas Used</span>
                <span className="font-mono text-on-surface">{result.gasUsed.toLocaleString()}</span>
              </div>
            )}

            {(result.status === 'fail' || result.status === 'error') && (
              <div className="p-3 rounded-xl bg-error/5 border border-error/20">
                <p className="text-[10px] text-error font-bold line-clamp-2">
                  {result.error || 'Execution Reverted'}
                </p>
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
                className="block w-full text-center py-2 bg-surface-container-high rounded-xl text-[10px] font-black text-primary transition-all border border-primary/5 hover:border-primary/20 uppercase tracking-widest"
              >
                Execution Trace
              </a>
            )}
          </div>
        )}

      {!isTargeted && !isUnsupported && (
        <div className="text-[10px] text-on-surface-variant font-bold uppercase tracking-widest text-center py-2 opacity-50">
          Idle
        </div>
      )}
    </div>
  )
}
