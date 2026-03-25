'use client'

import React, { useMemo, useState } from 'react'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { CrossChainProposal,Proposal } from '@/types/governance'

import { ChainTheme, getChainTheme } from '../config/chains'
import config from '../config/index.json'
import {
  addresToContractName,
  decodeCalldata,
  decodeCrossChainCalldata,
  isCrossChainExecution,
  SupportedNetworks,
} from '../services/validation'

// Timelock Controller ABI for executeBatch
const TIMELOCK_ABI = [
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'payloads', type: 'bytes[]' },
      { name: 'predecessor', type: 'bytes32' },
      { name: 'salt', type: 'bytes32' },
    ],
    name: 'executeBatch',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
] as const

// Chain ID to network name mapping
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
  const [validatedActions, setValidatedActions] = useState<Set<string>>(new Set())

  const toggleValidation = (id: string) => {
    setValidatedActions((prev) => {
      const newSet = new Set(prev)
      if (newSet.has(id)) {
        newSet.delete(id)
      } else {
        newSet.add(id)
      }
      return newSet
    })
  }

  const handleExecuteProposal = async (proposal: CrossChainProposal) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const proposalChainId = parseInt(proposal.chainId)
    const networkName = CHAIN_ID_TO_NETWORK[proposal.chainId]

    if (!networkName) {
      alert(`Unsupported chain ID: ${proposal.chainId}`)
      return
    }

    const timelockAddress = (config as any)[networkName]?.deployedContracts?.gov?.timelock?.address
    if (!timelockAddress) {
      alert(`Timelock address not found for chain ${networkName}`)
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      if (chainId !== proposalChainId) {
        await switchChain({ chainId: proposalChainId })
      }

      await writeContract({
        address: timelockAddress as `0x${string}`,
        abi: TIMELOCK_ABI,
        functionName: 'executeBatch',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`,
          proposal.salt as `0x${string}`,
        ],
      })
    } catch (error) {
      console.error('Error executing proposal:', error)
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const getCrossChainProposalStatus = (proposal: CrossChainProposal) => {
    if (proposal.status === 'Executed') return 'Executed'
    if (proposal.status === 'Pending') {
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const eta = Number(proposal.eta)
      if (eta > 0 && currentTimestamp < eta) return 'Queued'
      if (eta > 0 && currentTimestamp >= eta) return 'Ready'
    }
    return proposal.status
  }

  const truncateAddress = (address: string, maxLength = 20) => {
    if (address.length <= maxLength) return address
    return `${address.slice(0, 10)}...${address.slice(-8)}`
  }

  const formatArgDisplay = (arg: any, theme: ChainTheme): React.ReactNode => {
    if (arg === null || arg === undefined)
      return <span className="text-on-surface-variant italic opacity-50">null</span>

    // Handle Percentage/WAD-based strings from decoder
    if (typeof arg === 'string' && arg.includes('(') && arg.includes('%)')) {
      const [raw, percent] = arg.split(' (')
      return (
        <div className="flex items-baseline gap-2">
          <span className={`font-mono`} style={{ color: theme.color }}>
            {raw}
          </span>
          <span
            className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-1.5 py-0.5 rounded uppercase tracking-tighter border`}
            style={{ borderColor: `${theme.color}30` }}
          >
            {percent.replace(')', '')}
          </span>
        </div>
      )
    }

    // Handle Formatted Token Amounts from decoder
    if (typeof arg === 'string' && arg.includes('[formatted:')) {
      const match = arg.match(/^(.+?) \[formatted:(.+?)\]$/)
      if (match) {
        const [, raw, formattedPart] = match
        const isFallback = formattedPart.includes(':fallback')
        const formatted = formattedPart.replace(':fallback', '')

        return (
          <div className="flex flex-col gap-0.5">
            <div className="flex items-center gap-2">
              <span className={`font-medium`} style={{ color: theme.color }}>
                {formatted}
              </span>
              {isFallback && (
                <div className="group relative">
                  <span className="material-symbols-outlined text-amber-500 text-xs cursor-help">
                    warning
                  </span>
                  <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 p-2 bg-slate-900 text-white text-[10px] rounded shadow-xl opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50">
                    Decimals could not be resolved. Defaulted to 18.
                  </div>
                </div>
              )}
            </div>
            <span className="text-[10px] text-on-surface-variant font-mono opacity-40">
              Raw: {raw}
            </span>
          </div>
        )
      }
    }

    if (typeof arg === 'string' && arg.includes('#')) {
      const parts = arg.split('#')
      if (parts.length === 2) {
        const [networkAndContract, roleAndAddress] = parts
        const addressMatch = roleAndAddress.match(/\(([^)]+)\)$/)
        const addressResolved = addressMatch ? addressMatch[1] : ''
        const role = addressMatch ? roleAndAddress.replace(/\([^)]+\)$/, '') : roleAndAddress

        return (
          <div className="flex flex-col gap-0.5">
            <span className={`font-semibold truncate max-w-[300px]`} style={{ color: theme.color }}>
              {networkAndContract}#{role}
            </span>
            {addressResolved && (
              <span
                className={`text-[10px] text-on-surface-variant font-mono select-all truncate uppercase opacity-60`}
              >
                {addressResolved}
              </span>
            )}
          </div>
        )
      }
    }

    if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
      return (
        <span
          className={`font-mono text-xs select-all cursor-help`}
          style={{ color: theme.color }}
          title={arg}
        >
          {truncateAddress(arg, 32)}
        </span>
      )
    }

    if (
      typeof arg === 'bigint' ||
      (typeof arg === 'string' && /^\d+$/.test(arg) && arg.length > 15)
    ) {
      return (
        <span className={`font-mono`} style={{ color: theme.color }}>
          {arg.toString()}
        </span>
      )
    }

    if (Array.isArray(arg)) {
      if (arg.length === 0) return <span className="text-on-surface-variant">[]</span>
      return (
        <div className="space-y-1.5 pl-2 border-l mt-1" style={{ borderColor: `${theme.color}20` }}>
          {arg.map((item, i) => (
            <div key={i} className="flex gap-2">
              <span
                className={`text-[9px] text-on-surface-variant font-mono uppercase tracking-tighter`}
              >
                [{i}]:
              </span>
              {formatArgDisplay(item, theme)}
            </div>
          ))}
        </div>
      )
    }

    if (typeof arg === 'object' && arg !== null) {
      return (
        <div
          className="flex flex-col gap-1.5 pl-2 border-l mt-1"
          style={{ borderColor: `${theme.color}20` }}
        >
          {Object.entries(arg).map(([key, value]) => (
            <div key={key} className="text-[10px]">
              <span
                className={`text-on-surface-variant uppercase tracking-tighter block mb-0.5 opacity-60 font-bold`}
              >
                {key} :
              </span>
              {formatArgDisplay(value, theme)}
            </div>
          ))}
        </div>
      )
    }

    return <span style={{ color: theme.color }}>{String(arg)}</span>
  }

  // Group actions by Hub vs Satellite
  const { hubActions, satelliteContainers } = useMemo(() => {
    const hub: any[] = []
    const crossChainBlocks: Record<string, any> = {}

    if (!baseProposal.targets) return { hubActions: [], satelliteContainers: [] }

    baseProposal.targets.forEach((target, index) => {
      const value = baseProposal.values?.[index] || '0'
      const calldata = baseProposal.calldatas?.[index] || ''
      const isCrossChain = isCrossChainExecution(target, calldata)
      const contractName = addresToContractName(target, network)
      const validationId = `base-${index}-${target}-${value}`

      if (isCrossChain) {
        const decoded = decodeCrossChainCalldata(calldata)
        if (decoded) {
          hub.push({
            type: 'hub',
            index,
            target,
            value,
            contractName,
            validationId,
            isInitiator: true,
            dstEid: decoded.dstEid,
          })

          if (!crossChainBlocks[decoded.dstEid]) {
            crossChainBlocks[decoded.dstEid] = {
              chain: decoded.dstEid,
              actions: [],
            }
          }
          decoded.formattedProposals?.forEach((p, pIdx) => {
            crossChainBlocks[decoded.dstEid].actions.push({
              ...p,
              validationId: `intent-${index}-${p.target}-${pIdx}`,
            })
          })
        }
      } else {
        const decoded = decodeCalldata(calldata, target, network)
        hub.push({
          type: 'hub',
          index,
          target,
          value,
          contractName,
          validationId,
          decoded,
        })
      }
    })

    return {
      hubActions: hub,
      satelliteContainers: Object.values(crossChainBlocks),
    }
  }, [baseProposal, network])

  return (
    <div className="space-y-8">
      {/* HUB CHAIN CONTAINER */}
      {hubActions.length > 0 &&
        (() => {
          const theme = getChainTheme(network)
          return (
            <div
              className={`bg-slate-900/40 border rounded-xl overflow-hidden shadow-lg shadow-black/20`}
              style={{ borderColor: `${theme.color}20` }}
            >
              <div
                className={`px-5 py-4 flex items-center justify-between border-b ${theme.bg}`}
                style={{ borderColor: `${theme.color}30` }}
              >
                <div className="flex items-center gap-3">
                  <span className={`material-symbols-outlined ${theme.text} text-xl font-bold`}>
                    {theme.icon}
                  </span>
                  <span className={`text-xs font-bold uppercase tracking-widest ${theme.text}`}>
                    Hub Chain Execution
                  </span>
                </div>
                <span
                  className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-2 py-0.5 rounded uppercase border`}
                  style={{ borderColor: `${theme.color}50` }}
                >
                  {theme.name.toUpperCase()}
                </span>
              </div>

              <div className="p-5 space-y-8">
                {hubActions.map((action: any, i: number) => {
                  const isValidated = validatedActions.has(action.validationId)
                  return (
                    <div
                      key={i}
                      className={`space-y-4 transition-all duration-300 ${isValidated ? 'opacity-40 grayscale-[0.5]' : ''}`}
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex gap-3">
                          <input
                            type="checkbox"
                            checked={isValidated}
                            onChange={() => toggleValidation(action.validationId)}
                            className="w-4 h-4 mt-1 rounded border-outline/30 text-primary bg-slate-950 focus:ring-primary/20 cursor-pointer"
                          />
                          <div>
                            <p className="text-[10px] text-on-surface-variant uppercase tracking-widest font-bold mb-1">
                              Target
                            </p>
                            <p
                              className={`text-sm font-mono select-all`}
                              style={{ color: theme.color }}
                            >
                              {truncateAddress(action.target, 32)}
                            </p>
                            <p
                              className={`text-[10px] mt-0.5 font-medium opacity-60`}
                              style={{ color: theme.color }}
                            >
                              {action.contractName}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] text-on-surface-variant uppercase tracking-widest font-bold mb-1">
                            Value
                          </p>
                          <p className="text-sm font-mono font-bold text-on-surface">
                            {action.value === '0' ? '0 ETH' : `${action.value} wei`}
                          </p>
                        </div>
                      </div>

                      {action.isInitiator ? (
                        <div
                          className={`flex items-center gap-2 ${theme.bg} p-3 rounded-lg border`}
                          style={{ borderColor: `${theme.color}20` }}
                        >
                          <span className={`material-symbols-outlined text-sm ${theme.text}`}>
                            swap_calls
                          </span>
                          <span
                            className={`text-xs font-semibold tracking-tight uppercase ${theme.text}`}
                          >
                            Initiates Cross-Chain Proposal to {action.dstEid}
                          </span>
                        </div>
                      ) : (
                        action.decoded && (
                          <div className="space-y-3">
                            <div className="flex items-center gap-2" style={{ color: theme.color }}>
                              <span className="material-symbols-outlined text-sm">function</span>
                              <span className="text-sm font-bold uppercase tracking-tight">
                                {action.decoded.functionName}
                              </span>
                            </div>
                            <div
                              className={`p-4 bg-slate-950/40 rounded-lg border font-mono text-xs text-on-surface-variant space-y-4`}
                              style={{ borderColor: `${theme.color}10` }}
                            >
                              {action.decoded.args && action.decoded.args.length > 0 ? (
                                action.decoded.args.map((arg: any, argIndex: number) => (
                                  <div key={argIndex}>
                                    <p
                                      className={`text-[10px] uppercase mb-1 tracking-tighter font-bold opacity-60`}
                                      style={{ color: theme.color }}
                                    >
                                      {action.decoded?.paramNames?.[argIndex] || `ARG${argIndex}`} :
                                    </p>
                                    <div className="pl-1">{formatArgDisplay(arg, theme)}</div>
                                  </div>
                                ))
                              ) : (
                                <p className="text-[10px] italic opacity-50">No arguments</p>
                              )}
                            </div>
                          </div>
                        )
                      )}
                      {i < hubActions.length - 1 && (
                        <div
                          className="h-px w-full mx-auto"
                          style={{ backgroundColor: `${theme.color}05` }}
                        />
                      )}
                    </div>
                  )
                })}
              </div>
            </div>
          )
        })()}

      {/* SATELLITE CHAIN CONTAINERS */}
      {satelliteContainers.map((container: any, cIdx: number) => {
        const theme = getChainTheme(container.chain)
        return (
          <div
            key={cIdx}
            className="bg-slate-900/40 border rounded-xl overflow-hidden shadow-lg shadow-black/20"
            style={{ borderColor: `${theme.color}20` }}
          >
            <div
              className={`px-5 py-4 flex items-center justify-between border-b ${theme.bg}`}
              style={{ borderColor: `${theme.color}30` }}
            >
              <div className="flex items-center gap-3">
                <span className={`material-symbols-outlined ${theme.text} text-xl font-bold`}>
                  {theme.icon}
                </span>
                <span className={`text-xs font-bold uppercase tracking-widest ${theme.text}`}>
                  Cross-Chain Execution
                </span>
              </div>
              <span
                className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-2 py-0.5 rounded uppercase border`}
                style={{ borderColor: `${theme.color}50` }}
              >
                {container.chain.toUpperCase()}
              </span>
            </div>

            <div className="p-5 space-y-10">
              <div className="space-y-8">
                {container.actions.map((action: any, aIdx: number) => {
                  const isValidated = validatedActions.has(action.validationId)
                  return (
                    <div
                      key={aIdx}
                      className={`space-y-4 transition-all duration-300 ${isValidated ? 'opacity-40 grayscale-[0.5]' : ''}`}
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex gap-3">
                          <input
                            type="checkbox"
                            checked={isValidated}
                            onChange={() => toggleValidation(action.validationId)}
                            className="w-3.5 h-3.5 mt-1 rounded border-outline/30 text-primary bg-slate-950 focus:ring-primary/20 cursor-pointer"
                          />
                          <div>
                            <p className="text-[10px] text-on-surface-variant uppercase tracking-widest font-bold mb-1">
                              Target
                            </p>
                            <p
                              className={`text-sm font-mono select-all`}
                              style={{ color: theme.color }}
                            >
                              {truncateAddress(action.target, 32)}
                            </p>
                            <p
                              className={`text-[10px] mt-0.5 font-medium opacity-60`}
                              style={{ color: theme.color }}
                            >
                              {action.targetName}
                            </p>
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-[10px] text-on-surface-variant uppercase tracking-widest font-bold mb-1">
                            Value
                          </p>
                          <p className="text-sm font-mono font-bold text-on-surface">
                            {action.value === '0' ? '0 ETH' : `${action.value} wei`}
                          </p>
                        </div>
                      </div>

                      {action.decodedCall && (
                        <div className="space-y-3">
                          <div className="flex items-center gap-2" style={{ color: theme.color }}>
                            <span className="material-symbols-outlined text-sm font-bold">
                              function
                            </span>
                            <span className="text-sm font-bold uppercase tracking-tight">
                              {action.decodedCall.functionName}
                            </span>
                          </div>
                          <div
                            className={`p-4 bg-slate-950/40 rounded-lg border font-mono text-xs text-on-surface-variant space-y-4`}
                            style={{ borderColor: `${theme.color}10` }}
                          >
                            {action.decodedCall.args.map((arg: any, argIndex: number) => (
                              <div key={argIndex}>
                                <p
                                  className={`text-[10px] uppercase mb-1 tracking-tighter font-bold opacity-60`}
                                  style={{ color: theme.color }}
                                >
                                  {action.decodedCall?.paramNames?.[argIndex] || `ARG${argIndex}`} :
                                </p>
                                <div className="pl-1">{formatArgDisplay(arg, theme)}</div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                      {aIdx < container.actions.length - 1 && (
                        <div
                          className="h-px w-full mx-auto"
                          style={{ backgroundColor: `${theme.color}05` }}
                        />
                      )}
                    </div>
                  )
                })}
              </div>

              <div className="pt-8 border-t" style={{ borderColor: `${theme.color}20` }}>
                <p className="text-[10px] font-bold text-on-surface-variant uppercase tracking-widest mb-4">
                  Satellite Proposal Status
                </p>
                {crossChainProposals.filter(
                  (ccp) => CHAIN_ID_TO_NETWORK[ccp.chainId] === container.chain,
                ).length === 0 ? (
                  <div
                    className={`p-6 ${theme.bg} border border-dashed rounded-xl text-center`}
                    style={{ borderColor: `${theme.color}20` }}
                  >
                    <span
                      className={`material-symbols-outlined ${theme.text} opacity-30 text-3xl mb-2`}
                    >
                      pending_actions
                    </span>
                    <p className={`text-xs ${theme.text} opacity-60 font-medium tracking-tight`}>
                      No satellite proposal found on {container.chain} yet.
                    </p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {crossChainProposals
                      .filter((ccp) => CHAIN_ID_TO_NETWORK[ccp.chainId] === container.chain)
                      .map((ccp) => {
                        const status = getCrossChainProposalStatus(ccp)
                        const eta = Number(ccp.eta)

                        return (
                          <div
                            key={ccp.id}
                            className="p-4 bg-slate-950/30 rounded-xl border"
                            style={{ borderColor: `${theme.color}20` }}
                          >
                            <div className="flex justify-between items-center mb-4">
                              <div className="flex items-center gap-4">
                                <div className="flex flex-col">
                                  <span className="text-[9px] text-on-surface-variant font-bold uppercase tracking-widest mb-1">
                                    Status
                                  </span>
                                  <span
                                    className={`px-2 py-0.5 rounded text-[10px] font-bold w-fit ${
                                      status === 'Executed'
                                        ? 'bg-emerald-400/10 text-emerald-400 border border-emerald-400/20'
                                        : status === 'Ready'
                                          ? `${theme.bg} ${theme.text} border animate-pulse`
                                          : 'bg-slate-400/10 text-slate-400 border border-slate-400/20'
                                    }`}
                                    style={{
                                      borderColor:
                                        status === 'Ready' ? `${theme.color}40` : undefined,
                                    }}
                                  >
                                    {status.toUpperCase()}
                                  </span>
                                </div>
                              </div>

                              {(status === 'Ready' || status === 'Pending') && (
                                <button
                                  onClick={() => handleExecuteProposal(ccp)}
                                  disabled={executingProposals.has(ccp.id) || isPending}
                                  className={`px-4 py-2 rounded-lg text-xs font-bold hover:brightness-110 active:scale-95 transition-all shadow-lg disabled:opacity-50`}
                                  style={{ backgroundColor: theme.color, color: '#000' }}
                                >
                                  {executingProposals.has(ccp.id)
                                    ? 'Executing...'
                                    : 'Execute Satellite'}
                                </button>
                              )}
                            </div>

                            <div
                              className="grid grid-cols-2 gap-4 p-3 bg-slate-950/40 rounded-lg text-[10px] font-mono border"
                              style={{ borderColor: `${theme.color}10` }}
                            >
                              <div>
                                <span
                                  className={`block mb-1 uppercase font-bold tracking-tighter opacity-60`}
                                  style={{ color: theme.color }}
                                >
                                  Satellite ID
                                </span>
                                <span className="text-on-surface opacity-80 break-all">
                                  {ccp.id}
                                </span>
                              </div>
                              <div className="text-right">
                                <span
                                  className={`block mb-1 uppercase font-bold tracking-tighter text-right opacity-60`}
                                  style={{ color: theme.color }}
                                >
                                  ETA
                                </span>
                                <span className="text-on-surface">
                                  {eta > 0 ? new Date(eta * 1000).toLocaleString() : 'Not Set'}
                                </span>
                              </div>
                            </div>
                          </div>
                        )
                      })}
                  </div>
                )}
              </div>
            </div>
          </div>
        )
      })}

      {hubActions.length === 0 && satelliteContainers.length === 0 && (
        <div
          className="text-center py-12 bg-slate-900/40 rounded-xl border border-dashed border-sky-400/10"
          style={{ borderColor: getChainTheme(network).color + '20' }}
        >
          <span
            className="material-symbols-outlined text-4xl mb-3 opacity-30"
            style={{ color: getChainTheme(network).color }}
          >
            terminal
          </span>
          <p className="text-sm text-on-surface-variant">
            No executable actions found in this proposal.
          </p>
        </div>
      )}
    </div>
  )
}
