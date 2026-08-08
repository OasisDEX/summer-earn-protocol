'use client'

import React, { useMemo, useState } from 'react'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { CrossChainProposal, Proposal } from '@/types/governance'

import config from '../config/index.json'
import {
  addresToContractName,
  decodeCalldata,
  decodeCrossChainCalldata,
  DecodedAddress,
  isCrossChainExecution,
  SupportedNetworks,
} from '../services/validation'

const EXPLORER_URLS: Record<string, string> = {
  mainnet: 'https://etherscan.io/address/',
  base: 'https://basescan.org/address/',
  arbitrum: 'https://arbiscan.io/address/',
  sonic: 'https://sonicscan.org/address/',
  hyperliquid: 'https://explorer.hyperliquid.xyz/address/',
}

const CHAIN_ID_TO_NETWORK: Record<string, keyof typeof config> = {
  '1': 'mainnet',
  '8453': 'base',
  '42161': 'arbitrum',
  '146': 'sonic',
  '999': 'hyperliquid',
}

interface ProposalExecutionDetailsProps {
  baseProposal: Proposal
  crossChainProposals: CrossChainProposal[]
  network: SupportedNetworks
}

export const ProposalExecutionDetails: React.FC<ProposalExecutionDetailsProps> = ({
  baseProposal,
  crossChainProposals,
  network,
}) => {
  const { address, isConnected, chainId } = useAccount()
  const { writeContract, isPending } = useWriteContract()
  const { switchChain } = useSwitchChain()
  const [executingProposals, setExecutingProposals] = useState<Set<string>>(new Set())
  const [copiedIndex, setCopiedIndex] = useState<string | null>(null)

  const copyToClipboard = (text: string, id: string) => {
    navigator.clipboard.writeText(text)
    setCopiedIndex(id)
    setTimeout(() => setCopiedIndex(null), 2000)
  }

  return (
    <section className="border border-line rounded-xl bg-console-surface overflow-hidden">
      <div className="px-[18px] py-[13px] border-b border-line text-xs font-semibold text-fg">
        Proposed actions
      </div>

      {baseProposal.targets.map((target, index) => {
        const calldata = baseProposal.calldatas[index]
        const decoded = decodeCalldata(calldata, target, SupportedNetworks.BASE)
        const selector = calldata.slice(0, 10)

        return (
          <div key={index} className="p-[18px] border-b border-line">
            <div className="flex items-baseline gap-3 flex-wrap mb-3">
              <span className="text-[10px] font-semibold tracking-wider uppercase text-fg3 whitespace-nowrap">
                Action {index + 1}
              </span>
              <span className="flex-1 min-w-0 text-xs text-fg2 font-mono">
                Base · 8453 (hub direct execution)
              </span>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-2.5 mb-3">
              <div className="bg-surface2 p-2.5 rounded-lg border border-line">
                <span className="block text-[10px] font-semibold tracking-wider uppercase text-fg3 mb-1">
                  Target address
                </span>
                <span className="font-mono text-xs text-fg break-all">{target}</span>
              </div>

              <div className="bg-surface2 p-2.5 rounded-lg border border-line">
                <span className="block text-[10px] font-semibold tracking-wider uppercase text-fg3 mb-1">
                  Function method
                </span>
                <span className="font-mono text-xs text-fg break-all">
                  {decoded?.functionName || 'Unknown, encode and verify'}
                </span>
              </div>

              <div className="bg-surface2 p-2.5 rounded-lg border border-line">
                <span className="block text-[10px] font-semibold tracking-wider uppercase text-fg3 mb-1">
                  Selector
                </span>
                <span className="font-mono text-xs text-brand-pink">{selector}</span>
              </div>
            </div>

            {decoded && decoded.args && decoded.args.length > 0 && (
              <div className="p-3 rounded-lg border border-line bg-surface2 mb-3">
                <span className="block text-[10px] font-semibold tracking-wider uppercase text-fg3 mb-2">
                  Parameters
                </span>
                <div className="space-y-1.5 font-mono text-xs">
                  {decoded.args.map((arg, ai) => {
                    const paramName = decoded.paramNames?.[ai] || `arg${ai}`
                    return (
                      <div key={ai} className="flex justify-between items-center gap-2">
                        <span className="text-fg2">{paramName}</span>
                        <span className="text-fg break-all">
                          {typeof arg === 'object' ? JSON.stringify(arg) : String(arg)}
                        </span>
                      </div>
                    )
                  })}
                </div>
              </div>
            )}

            <div className="flex justify-end">
              <button
                onClick={() => copyToClipboard(calldata, `action-${index}`)}
                className="h-[28px] px-2.5 rounded-md border border-line2 bg-surface3 text-fg text-xs font-medium cursor-pointer hover:bg-surface2 transition-colors"
              >
                {copiedIndex === `action-${index}` ? 'Copied!' : 'Copy full calldata'}
              </button>
            </div>
          </div>
        )
      })}
    </section>
  )
}
