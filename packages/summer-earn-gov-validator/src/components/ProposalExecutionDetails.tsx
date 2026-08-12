'use client'

import React, { useMemo, useState } from 'react'
import { AlertTriangle, Clock, Gauge, Layers, Network, Repeat, Terminal, Zap } from 'lucide-react'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { CrossChainProposal, Proposal } from '@/types/governance'

import { ChainTheme, getChainTheme } from '../config/chains'
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

const getExplorerUrl = (address: string, chainId: string) => {
  const networkName = CHAIN_ID_TO_NETWORK[chainId] || 'base'
  const baseUrl = EXPLORER_URLS[networkName as string] || EXPLORER_URLS.base
  return `${baseUrl}${address}`
}

// Chain theme `icon` values map to material-symbol names; translate to lucide icons here.
const CHAIN_ICON: Record<
  string,
  React.ComponentType<{ className?: string; style?: React.CSSProperties }>
> = {
  hub: Network,
  layers: Layers,
  swap_calls: Repeat,
  bolt: Zap,
  speed: Gauge,
}

const ChainIcon = ({ theme, className }: { theme: ChainTheme; className?: string }) => {
  const Icon = CHAIN_ICON[theme.icon] || Network
  return <Icon className={className} style={{ color: theme.color }} />
}

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

  const formatArgDisplay = (arg: any, theme: ChainTheme): React.ReactNode => {
    if (arg === null || arg === undefined)
      return <span className="text-fg2 italic opacity-50">null</span>

    // Handle Percentage/WAD-based strings from decoder
    if (typeof arg === 'string' && arg.includes('(') && arg.includes('%)')) {
      const [raw, percent] = arg.split(' (')
      return (
        <div className="flex items-baseline gap-2">
          <span className="font-mono" style={{ color: theme.color }}>
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
              <span className="font-medium" style={{ color: theme.color }}>
                {formatted}
              </span>
              {isFallback && (
                <div className="group relative">
                  <AlertTriangle className="w-3 h-3 text-warn cursor-help" />
                  <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 p-2 bg-surface3 text-fg text-[10px] rounded shadow-xl opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-50 border border-line">
                    Decimals could not be resolved. Defaulted to 18.
                  </div>
                </div>
              )}
            </div>
            <span className="text-[10px] text-fg2 font-mono opacity-40">Raw: {raw}</span>
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
            <span className="font-semibold truncate max-w-[300px]" style={{ color: theme.color }}>
              {networkAndContract}#{role}
            </span>
            {addressResolved && (
              <span className="text-[10px] text-fg2 font-mono select-all truncate uppercase opacity-60">
                {addressResolved}
              </span>
            )}
          </div>
        )
      }
    }

    if (
      typeof arg === 'object' &&
      arg !== null &&
      'address' in arg &&
      'explorerUrl' in arg &&
      'name' in arg
    ) {
      const decodedAddr = arg as DecodedAddress
      const isUnknown = decodedAddr.name === 'unknown'
      return (
        <div className="flex flex-col gap-0.5 mt-1">
          {!isUnknown ? (
            <span
              className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-2 py-0.5 rounded uppercase tracking-tighter border w-fit`}
              style={{ borderColor: `${theme.color}30` }}
            >
              {decodedAddr.name}
            </span>
          ) : (
            <div className="flex items-center gap-1 text-[10px] text-warn font-bold uppercase tracking-tighter">
              <AlertTriangle className="w-3 h-3" />
              <span>Unrecognized</span>
            </div>
          )}
          <a
            href={decodedAddr.explorerUrl}
            target="_blank"
            rel="noopener noreferrer"
            className={`font-mono text-xs select-all hover:underline ${isUnknown ? 'text-warn italic' : ''}`}
            style={!isUnknown ? { color: theme.color } : {}}
            title={decodedAddr.address}
          >
            {decodedAddr.address}
          </a>
        </div>
      )
    }

    if (typeof arg === 'string' && arg.startsWith('0x') && arg.length === 42) {
      return (
        <span
          className="font-mono text-xs select-all cursor-help"
          style={{ color: theme.color }}
          title={arg}
        >
          {arg}
        </span>
      )
    }

    if (
      typeof arg === 'bigint' ||
      (typeof arg === 'string' && /^\d+$/.test(arg) && arg.length > 15)
    ) {
      return (
        <span className="font-mono" style={{ color: theme.color }}>
          {arg.toString()}
        </span>
      )
    }

    if (Array.isArray(arg)) {
      if (arg.length === 0) return <span className="text-fg2">[]</span>
      return (
        <div className="space-y-1.5 pl-2 border-l mt-1" style={{ borderColor: `${theme.color}20` }}>
          {arg.map((item, i) => (
            <div key={i} className="flex gap-2">
              <span className="text-[9px] text-fg2 font-mono uppercase tracking-tighter">
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
              <span className="text-fg2 uppercase tracking-tighter block mb-0.5 opacity-60 font-bold">
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
    <div className="space-y-3.5">
      {/* HUB CHAIN CONTAINER */}
      {hubActions.length > 0 &&
        (() => {
          const theme = getChainTheme(network)
          return (
            <div className="border border-line rounded-xl bg-console-surface overflow-hidden">
              <div className="px-4 py-3.5 flex items-center gap-2.5 border-b border-line flex-wrap">
                <span className="px-2 py-0.5 rounded text-[10px] font-bold tracking-wider uppercase bg-pink-bg text-brand-pink">
                  Hub
                </span>
                <ChainIcon theme={theme} className="w-4 h-4" />
                <span className="text-[13px] font-semibold text-fg">{theme.name}</span>
              </div>

              <div className="divide-y divide-line">
                {hubActions.map((action: any, i: number) => {
                  const isValidated = validatedActions.has(action.validationId)
                  return (
                    <div
                      key={i}
                      className={`flex gap-3 p-4 transition-all duration-300 ${
                        isValidated ? 'opacity-40 grayscale-[0.5]' : ''
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={isValidated}
                        onChange={() => toggleValidation(action.validationId)}
                        className="w-4 h-4 mt-1 rounded border-line2 text-brand-pink bg-field focus:ring-brand-pink/20 cursor-pointer shrink-0"
                      />

                      <div className="flex-1 min-w-0 space-y-3">
                        <div className="flex justify-between items-start gap-3 flex-wrap">
                          <div className="min-w-0">
                            <p className="text-[10px] text-fg3 uppercase tracking-[0.07em] font-semibold mb-1">
                              Target
                            </p>
                            <div className="flex items-center gap-2 flex-wrap">
                              <a
                                href={getExplorerUrl(
                                  action.target,
                                  baseProposal.chains[0] || '8453',
                                )}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="text-xs font-mono select-all hover:underline"
                                style={{ color: theme.color }}
                              >
                                {action.target}
                              </a>
                              {action.contractName !== 'unknown' && (
                                <span
                                  className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-2 py-0.5 rounded uppercase tracking-tighter border`}
                                  style={{ borderColor: `${theme.color}30` }}
                                >
                                  {action.contractName}
                                </span>
                              )}
                            </div>
                          </div>
                          <div className="text-right shrink-0">
                            <p className="text-[10px] text-fg3 uppercase tracking-[0.07em] font-semibold mb-1">
                              Value
                            </p>
                            <p className="text-xs font-mono font-semibold text-fg">
                              {action.value === '0' ? '0 ETH' : `${action.value} wei`}
                            </p>
                          </div>
                        </div>

                        {action.contractName === 'unknown' && (
                          <div className="bg-warn-bg border border-warn/20 p-3 rounded-lg flex items-center gap-2.5">
                            <AlertTriangle className="w-4 h-4 text-warn shrink-0" />
                            <p className="text-[11px] text-warn font-medium">
                              Target address <span className="font-mono">{action.target}</span> not
                              found in known contract registry. Manual verification recommended.
                            </p>
                          </div>
                        )}

                        {action.isInitiator ? (
                          <div className="flex items-center gap-2 bg-info-bg text-info p-2.5 rounded-lg">
                            <Repeat className="w-3.5 h-3.5" />
                            <span className="text-[11px] font-semibold tracking-tight uppercase">
                              Initiates cross-chain proposal to {action.dstEid}
                            </span>
                          </div>
                        ) : (
                          action.decoded && (
                            <div className="space-y-2">
                              <div className="flex items-center gap-2">
                                <Terminal className="w-3.5 h-3.5" style={{ color: theme.color }} />
                                <span
                                  className="text-sm font-mono font-semibold"
                                  style={{ color: theme.color }}
                                >
                                  {action.decoded.functionName}
                                </span>
                              </div>
                              {action.decoded.args && action.decoded.args.length > 0 ? (
                                <div className="space-y-2">
                                  {action.decoded.args.map((arg: any, argIndex: number) => (
                                    <div
                                      key={argIndex}
                                      className="border border-line rounded-lg bg-surface2 p-2.5"
                                    >
                                      <p className="text-[10px] uppercase mb-1 tracking-[0.07em] font-semibold text-fg3">
                                        {action.decoded?.paramNames?.[argIndex] || `arg${argIndex}`}
                                      </p>
                                      <div>{formatArgDisplay(arg, theme)}</div>
                                    </div>
                                  ))}
                                </div>
                              ) : (
                                <p className="text-[10px] italic text-fg3">No arguments</p>
                              )}
                            </div>
                          )
                        )}
                      </div>
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
            className="border border-line rounded-xl bg-console-surface overflow-hidden"
          >
            <div className="px-4 py-3.5 flex items-center gap-2.5 border-b border-line flex-wrap">
              <span className="px-2 py-0.5 rounded text-[10px] font-bold tracking-wider uppercase bg-info-bg text-info">
                Satellite
              </span>
              <ChainIcon theme={theme} className="w-4 h-4" />
              <span className="text-[13px] font-semibold text-fg">{theme.name}</span>
              <span className="text-[11px] text-fg3">{container.actions.length} action(s)</span>
            </div>

            <div className="divide-y divide-line">
              {container.actions.map((action: any, aIdx: number) => {
                const isValidated = validatedActions.has(action.validationId)
                return (
                  <div
                    key={aIdx}
                    className={`flex gap-3 p-4 transition-all duration-300 ${
                      isValidated ? 'opacity-40 grayscale-[0.5]' : ''
                    }`}
                  >
                    <input
                      type="checkbox"
                      checked={isValidated}
                      onChange={() => toggleValidation(action.validationId)}
                      className="w-4 h-4 mt-1 rounded border-line2 text-brand-pink bg-field focus:ring-brand-pink/20 cursor-pointer shrink-0"
                    />

                    <div className="flex-1 min-w-0 space-y-3">
                      <div className="flex justify-between items-start gap-3 flex-wrap">
                        <div className="min-w-0">
                          <p className="text-[10px] text-fg3 uppercase tracking-[0.07em] font-semibold mb-1">
                            Target
                          </p>
                          <div className="flex items-center gap-2 flex-wrap">
                            <a
                              href={getExplorerUrl(action.target, container.chain)}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-xs font-mono select-all hover:underline"
                              style={{ color: theme.color }}
                            >
                              {action.target}
                            </a>
                            {action.targetName !== 'unknown' && (
                              <span
                                className={`text-[10px] font-bold ${theme.bg} ${theme.text} px-2 py-0.5 rounded uppercase tracking-tighter border`}
                                style={{ borderColor: `${theme.color}30` }}
                              >
                                {action.targetName}
                              </span>
                            )}
                          </div>
                        </div>
                        <div className="text-right shrink-0">
                          <p className="text-[10px] text-fg3 uppercase tracking-[0.07em] font-semibold mb-1">
                            Value
                          </p>
                          <p className="text-xs font-mono font-semibold text-fg">
                            {action.value === '0' ? '0 ETH' : `${action.value} wei`}
                          </p>
                        </div>
                      </div>

                      {action.targetName === 'unknown' && (
                        <div className="bg-warn-bg border border-warn/20 p-3 rounded-lg flex items-center gap-2.5">
                          <AlertTriangle className="w-4 h-4 text-warn shrink-0" />
                          <p className="text-[11px] text-warn font-medium">
                            Target address <span className="font-mono">{action.target}</span> not
                            found in known contract registry. Manual verification recommended.
                          </p>
                        </div>
                      )}

                      {action.decodedCall && (
                        <div className="space-y-2">
                          <div className="flex items-center gap-2">
                            <Terminal className="w-3.5 h-3.5" style={{ color: theme.color }} />
                            <span
                              className="text-sm font-mono font-semibold"
                              style={{ color: theme.color }}
                            >
                              {action.decodedCall.functionName}
                            </span>
                          </div>
                          <div className="space-y-2">
                            {action.decodedCall.args.map((arg: any, argIndex: number) => (
                              <div
                                key={argIndex}
                                className="border border-line rounded-lg bg-surface2 p-2.5"
                              >
                                <p className="text-[10px] uppercase mb-1 tracking-[0.07em] font-semibold text-fg3">
                                  {action.decodedCall?.paramNames?.[argIndex] || `arg${argIndex}`}
                                </p>
                                <div>{formatArgDisplay(arg, theme)}</div>
                              </div>
                            ))}
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>

            <div className="p-4 border-t border-line">
              <p className="text-[10px] font-semibold text-fg3 uppercase tracking-[0.07em] mb-3">
                Satellite proposal status
              </p>
              {crossChainProposals.filter(
                (ccp) => CHAIN_ID_TO_NETWORK[ccp.chainId] === container.chain,
              ).length === 0 ? (
                <div className="p-5 bg-surface2 border border-dashed border-line rounded-lg text-center">
                  <Clock className="w-6 h-6 mx-auto mb-2 text-fg3 opacity-50" />
                  <p className="text-xs text-fg3">
                    No satellite proposal found on {container.chain} yet.
                  </p>
                </div>
              ) : (
                <div className="space-y-3">
                  {crossChainProposals
                    .filter((ccp) => CHAIN_ID_TO_NETWORK[ccp.chainId] === container.chain)
                    .map((ccp) => {
                      const status = getCrossChainProposalStatus(ccp)
                      const eta = Number(ccp.eta)

                      return (
                        <div
                          key={ccp.id}
                          className="p-3.5 bg-surface2 rounded-lg border border-line"
                        >
                          <div className="flex justify-between items-center mb-3 gap-2.5 flex-wrap">
                            <div className="flex flex-col gap-1">
                              <span className="text-[9px] text-fg3 font-semibold uppercase tracking-[0.07em]">
                                Status
                              </span>
                              <span
                                className={`px-2 py-0.5 rounded text-[10px] font-semibold w-fit uppercase ${
                                  status === 'Executed'
                                    ? 'bg-ok-bg text-ok'
                                    : status === 'Ready'
                                      ? `${theme.bg} ${theme.text}`
                                      : 'bg-surface3 text-fg3'
                                }`}
                              >
                                {status}
                              </span>
                            </div>

                            {(status === 'Ready' || status === 'Pending') && (
                              <button
                                onClick={() => handleExecuteProposal(ccp)}
                                disabled={executingProposals.has(ccp.id) || isPending}
                                className="px-3.5 py-2 rounded-lg text-xs font-semibold hover:brightness-110 active:scale-95 transition-all disabled:opacity-50"
                                style={{ backgroundColor: theme.color, color: '#000' }}
                              >
                                {executingProposals.has(ccp.id)
                                  ? 'Executing...'
                                  : 'Execute satellite'}
                              </button>
                            )}
                          </div>

                          <div className="grid grid-cols-2 gap-3 p-2.5 bg-field rounded-lg text-[10px] font-mono border border-line">
                            <div>
                              <span className="block mb-1 uppercase font-semibold tracking-[0.07em] text-fg3">
                                Satellite ID
                              </span>
                              <span className="text-fg2 break-all">{ccp.id}</span>
                            </div>
                            <div className="text-right">
                              <span className="block mb-1 uppercase font-semibold tracking-[0.07em] text-fg3 text-right">
                                ETA
                              </span>
                              <span className="text-fg2">
                                {eta > 0 ? new Date(eta * 1000).toLocaleString() : 'Not set'}
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
        )
      })}

      {hubActions.length === 0 && satelliteContainers.length === 0 && (
        <div className="text-center py-12 bg-console-surface rounded-xl border border-dashed border-line">
          <Terminal className="w-8 h-8 mx-auto mb-3 text-fg3 opacity-50" />
          <p className="text-sm text-fg3">No executable actions found in this proposal.</p>
        </div>
      )}
    </div>
  )
}
