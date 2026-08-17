import React, { useCallback, useEffect, useState } from 'react'
import { keccak256, stringToBytes } from 'viem'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { CrossChainProposal, Proposal, ProposalWithCrossChain } from '@/types/governance'
import { stripMarkdownForPreview } from '@/utils/text'
import { calculateProposalTiming } from '@/utils/timing'

import { getNormalizedChainInfo } from '../config/chains'
import config from '../config/index.json'
import { GOVERNOR_ABI, useMultipleProposalVoting, VoteSupport } from '../hooks/useProposalVoting'
import { fetchAllProposals } from '../services/subgraph'
import { PhaseIndicator } from './PhaseIndicator'
import { ProposalFilter, ProposalStatus } from './ProposalFilter'

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

// Helper function to calculate effective proposal status
const getEffectiveProposalStatus = (proposal: Proposal) => {
  const baseStatus = proposal.status.toUpperCase()
  const currentTimestamp = Math.floor(Date.now() / 1000)
  const createdAt = Number(proposal.createdAt)
  const votingDelay = 24 * 60 * 60 // 24 hours in seconds
  const votingPeriod = 3 * 24 * 60 * 60 // 3 days in seconds
  const votingStartTime = createdAt + votingDelay
  const votingEndTime = votingStartTime + votingPeriod

  // Check if PENDING proposal should be ACTIVE
  const isVotingActive =
    baseStatus === 'PENDING' &&
    currentTimestamp >= votingStartTime &&
    currentTimestamp < votingEndTime

  // Check if ACTIVE proposal should be SUCCEEDED (voting period ended)
  const isVotingEnded =
    (baseStatus === 'ACTIVE' ||
      (baseStatus === 'PENDING' && currentTimestamp >= votingStartTime)) &&
    currentTimestamp >= votingEndTime

  if (isVotingActive) return 'ACTIVE'
  if (isVotingEnded) return 'SUCCEEDED'
  return baseStatus
}

export const CrossChainProposals: React.FC = () => {
  const [proposals, setProposals] = useState<ProposalWithCrossChain[]>([])
  const [filteredProposals, setFilteredProposals] = useState<ProposalWithCrossChain[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [executingProposals, setExecutingProposals] = useState<Set<string>>(new Set())
  const [votingProposals, setVotingProposals] = useState<Set<string>>(new Set())
  const [selectedStatuses, setSelectedStatuses] = useState<ProposalStatus[]>([
    'Active',
    'Pending',
    'Succeeded',
    'Queued',
    'Ready',
    'Executed',
  ])

  const { address, isConnected, chainId } = useAccount()
  const { writeContract, isPending } = useWriteContract()
  const { switchChainAsync } = useSwitchChain()

  // Get active proposal IDs for voting data (including PENDING proposals that are now active)
  const activeProposalIds = filteredProposals
    .filter(({ baseProposal }) => getEffectiveProposalStatus(baseProposal) === 'ACTIVE')
    .map(({ baseProposal }) => baseProposal.id)

  // Use the voting hook to get all voting data
  const {
    proposalData,
    votingPower,
    refetch: refetchVotingData,
  } = useMultipleProposalVoting(activeProposalIds)

  const handleExecuteProposal = async (proposal: CrossChainProposal) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const { chainId: proposalChainId, networkName } = getNormalizedChainInfo(proposal.chainId)

    if (!networkName || isNaN(proposalChainId)) {
      alert(`Unsupported chain ID: ${proposal.chainId}`)
      return
    }

    // Get timelock address from config
    const timelockAddress = (config as Record<string, any>)[networkName]?.deployedContracts?.gov
      ?.timelock?.address
    if (!timelockAddress) {
      alert(`Timelock address not found for chain ${networkName}`)
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch chain if needed
      if (chainId !== proposalChainId) {
        await switchChainAsync({ chainId: proposalChainId })
      }

      // Convert values from string to bigint
      const values = proposal.values.map((v) => BigInt(v))

      // Execute the proposal
      await writeContract({
        chainId: proposalChainId,
        address: timelockAddress as `0x${string}`,
        abi: TIMELOCK_ABI,
        functionName: 'executeBatch',
        args: [
          proposal.targets as `0x${string}`[],
          values,
          proposal.calldatas as `0x${string}`[],
          '0x0000000000000000000000000000000000000000000000000000000000000000' as `0x${string}`, // predecessor
          proposal.salt as `0x${string}`,
        ],
      })

      console.log(`Successfully executed proposal ${proposal.id} on chain ${proposal.chainId}`)

      // Refresh proposals after execution
      setTimeout(() => {
        loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error executing proposal:', error)
      alert(
        `Failed to execute proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const handleExecuteBaseProposal = async (proposal: {
    id: string
    targets: string[]
    values: string[]
    calldatas: string[]
    description: string
  }) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const networkName = 'base'
    const governorAddress = config[networkName]?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChainAsync({ chainId: 8453 })
      }

      // Create description hash
      const descriptionHash = keccak256(stringToBytes(proposal.description))

      // Execute the proposal
      await writeContract({
        chainId: 8453,
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'execute',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
        ],
      })

      console.log(`Successfully executed base proposal ${proposal.id}`)

      // Refresh proposals after execution
      setTimeout(() => {
        loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error executing base proposal:', error)
      alert(
        `Failed to execute base proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const handleQueueBaseProposal = async (proposal: {
    id: string
    targets: string[]
    values: string[]
    calldatas: string[]
    description: string
  }) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const networkName = 'base'
    const governorAddress = config[networkName]?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChainAsync({ chainId: 8453 })
      }

      // Create description hash
      const descriptionHash = keccak256(stringToBytes(proposal.description))

      // Queue the proposal

      writeContract({
        chainId: 8453,
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'queue',
        args: [
          proposal.targets as `0x${string}`[],
          proposal.values.map((v) => BigInt(v)),
          proposal.calldatas as `0x${string}`[],
          descriptionHash as `0x${string}`,
        ],
      })

      setTimeout(() => {
        void loadProposals()
      }, 2000)
    } catch (error) {
      console.error('Error queueing base proposal:', error)
      alert(
        `Failed to queue base proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setExecutingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposal.id)
        return newSet
      })
    }
  }

  const handleVote = async (proposalId: string, support: VoteSupport) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const governorAddress = config.base?.deployedContracts?.govV2?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setVotingProposals((prev) => new Set(prev).add(proposalId))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChainAsync({ chainId: 8453 })
      }

      // Cast the vote
      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support],
      })

      console.log(`Successfully voted ${support} on proposal ${proposalId}`)

      // Refresh voting data after voting
      setTimeout(() => {
        void refetchVotingData()
      }, 2000)
    } catch (error) {
      console.error('Error voting on proposal:', error)
      alert(
        `Failed to vote on proposal: ${error instanceof Error ? error.message : 'Unknown error'}`,
      )
    } finally {
      setVotingProposals((prev) => {
        const newSet = new Set(prev)
        newSet.delete(proposalId)
        return newSet
      })
    }
  }

  const getCrossChainProposalStatus = useCallback(
    (proposal: CrossChainProposal): ProposalStatus => {
      if (proposal.status === 'Executed') return 'Executed'
      if (proposal.status === 'Pending') {
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const eta = Number(proposal.eta)
        if (eta > 0 && currentTimestamp < eta) {
          return 'Queued'
        } else if (eta > 0 && currentTimestamp >= eta) {
          return 'Ready'
        }
      }
      return proposal.status as ProposalStatus
    },
    [],
  )

  const filterProposals = useCallback(
    (proposals: ProposalWithCrossChain[], statuses: ProposalStatus[]) => {
      const filtered = proposals.filter((proposal) => {
        // Get the effective status for filtering
        const effectiveStatus = getEffectiveProposalStatus(proposal.baseProposal)
        const currentTimestamp = Math.floor(Date.now() / 1000)
        const baseEta = Number(proposal.baseProposal.eta)
        const isBaseReady =
          effectiveStatus === 'QUEUED' && baseEta > 0 && currentTimestamp >= baseEta

        const baseStatusMatches = statuses.some((status) => {
          if (status === 'Queued' && effectiveStatus === 'QUEUED' && !isBaseReady) return true
          if (status === 'Ready' && isBaseReady) return true
          if (status === 'Executed' && effectiveStatus === 'EXECUTED') return true
          if (status === 'Active' && effectiveStatus === 'ACTIVE') return true
          if (status === 'Succeeded' && effectiveStatus === 'SUCCEEDED') return true
          if (status === 'Pending' && effectiveStatus === 'PENDING') return true
          return false
        })

        // If base proposal matches, include it regardless of cross-chain status
        if (baseStatusMatches) return true

        // Then check if any cross-chain proposal matches the selected statuses
        const crossChainStatusMatches = proposal.crossChainProposals.some((ccp) => {
          const ccpStatus = getCrossChainProposalStatus(ccp)
          return statuses.includes(ccpStatus)
        })

        return crossChainStatusMatches
      })

      setFilteredProposals(filtered)
    },
    [getCrossChainProposalStatus],
  )

  const loadProposals = useCallback(async () => {
    try {
      const data = await fetchAllProposals()
      setProposals(data)
      filterProposals(data, selectedStatuses)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load proposals')
    } finally {
      setLoading(false)
    }
  }, [filterProposals, selectedStatuses])

  useEffect(() => {
    void loadProposals()
  }, [loadProposals])

  useEffect(() => {
    filterProposals(proposals, selectedStatuses)
  }, [filterProposals, proposals, selectedStatuses])

  if (loading)
    return (
      <div className="flex justify-center items-center min-h-[200px]">
        <div className="animate-pulse flex flex-col items-center space-y-4">
          <div className="h-8 w-32 bg-surface3 rounded"></div>
          <div className="h-4 w-24 bg-surface3 rounded"></div>
        </div>
      </div>
    )
  if (error)
    return (
      <div className="text-crit p-4 border border-crit/30 rounded-xl bg-crit-bg">
        <div className="flex items-center space-x-2">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
            />
          </svg>
          <span>Error: {error}</span>
        </div>
      </div>
    )

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div className="text-xs text-fg3 font-mono">{filteredProposals.length} proposals</div>
      </div>

      <div className="space-y-4">
        <ProposalFilter selectedStatuses={selectedStatuses} onStatusChange={setSelectedStatuses} />

        {isConnected && votingPower !== undefined && (
          <div className="border border-line rounded-xl bg-console-surface p-4">
            <div className="flex items-center justify-between">
              <h3 className="text-sm font-semibold text-fg">Your Voting Power</h3>
              <span className="font-mono text-xl font-medium text-fg">
                {(Number(votingPower) / 1e18).toLocaleString(undefined, {
                  maximumFractionDigits: 2,
                })}{' '}
                SUMR
              </span>
            </div>
            <p className="text-xs text-fg3 mt-1">
              This is your current voting power including decay adjustments
            </p>
          </div>
        )}
      </div>

      <div className="grid gap-3">
        {filteredProposals.map(({ baseProposal, crossChainProposals }) => {
          const baseStatus = baseProposal.status.toUpperCase()
          const currentTimestamp = Math.floor(Date.now() / 1000)
          const baseEta = Number(baseProposal.eta)
          const isBaseQueued = baseStatus === 'QUEUED'
          const isBaseReady = isBaseQueued && baseEta > 0 && currentTimestamp >= baseEta

          // Get the effective status (handles PENDING → ACTIVE transition)
          const effectiveStatus = getEffectiveProposalStatus(baseProposal)

          // Calculate timing information
          const timing = calculateProposalTiming({
            status: baseProposal.status,
            createdAt: baseProposal.createdAt,
          })

          return (
            <div
              key={baseProposal.id}
              className="border border-line rounded-xl p-4 space-y-3.5 bg-console-surface"
            >
              <div className="space-y-4">
                <div className="flex justify-between items-start">
                  <div className="space-y-1">
                    <h3 className="text-base font-semibold text-fg">Proposal #{baseProposal.id}</h3>
                    <p className="text-xs text-fg3">
                      Created on{' '}
                      {new Date(Number(baseProposal.createdAt) * 1000).toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`px-2.5 py-1 rounded-full text-[11px] font-semibold transition-colors ${
                        effectiveStatus === 'EXECUTED'
                          ? 'bg-ok-bg text-ok'
                          : effectiveStatus === 'SUCCEEDED'
                            ? 'bg-ok-bg text-ok'
                            : isBaseReady
                              ? 'bg-warn-bg text-warn'
                              : isBaseQueued
                                ? 'bg-warn-bg text-warn'
                                : effectiveStatus === 'ACTIVE'
                                  ? 'bg-info-bg text-info'
                                  : 'bg-surface3 text-fg3'
                      }`}
                    >
                      {isBaseReady ? 'Ready' : effectiveStatus}
                    </span>
                    {effectiveStatus === 'SUCCEEDED' && (
                      <button
                        onClick={() => handleQueueBaseProposal(baseProposal)}
                        disabled={executingProposals.has(baseProposal.id) || isPending}
                        className={`h-[30px] px-3 text-white text-xs font-semibold rounded-lg transition-colors flex items-center space-x-1.5 ${
                          executingProposals.has(baseProposal.id) || isPending
                            ? 'bg-surface3 text-fg3 cursor-not-allowed'
                            : 'bg-brand-pink hover:brightness-110'
                        }`}
                      >
                        {executingProposals.has(baseProposal.id) || isPending ? (
                          <>
                            <svg
                              className="w-4 h-4 animate-spin"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            <span>Queueing...</span>
                          </>
                        ) : (
                          <>
                            <svg
                              className="w-4 h-4"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                            <span>Queue</span>
                          </>
                        )}
                      </button>
                    )}
                    {(isBaseReady || isBaseQueued) && (
                      <button
                        onClick={() => handleExecuteBaseProposal(baseProposal)}
                        disabled={
                          executingProposals.has(baseProposal.id) ||
                          isPending ||
                          (!isBaseReady && isBaseQueued)
                        }
                        className={`h-[30px] px-3 text-white text-xs font-semibold rounded-lg transition-colors flex items-center space-x-1.5 ${
                          executingProposals.has(baseProposal.id) ||
                          isPending ||
                          (!isBaseReady && isBaseQueued)
                            ? 'bg-surface3 text-fg3 cursor-not-allowed'
                            : 'bg-brand-pink hover:brightness-110'
                        }`}
                      >
                        {executingProposals.has(baseProposal.id) || isPending ? (
                          <>
                            <svg
                              className="w-4 h-4 animate-spin"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                              />
                            </svg>
                            <span>Executing...</span>
                          </>
                        ) : (
                          <>
                            <svg
                              className="w-4 h-4"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                              />
                            </svg>
                            <span>Execute</span>
                          </>
                        )}
                      </button>
                    )}
                  </div>
                </div>

                {/* Timing Information */}
                <div className="border border-line rounded-xl bg-console-surface p-4">
                  <PhaseIndicator timing={timing} variant="default" />
                </div>

                <p className="text-fg2 text-sm leading-relaxed bg-surface2 p-3 rounded-lg border border-line">
                  {(() => {
                    const preview = stripMarkdownForPreview(baseProposal.description)
                    return preview.length > 160 ? `${preview.slice(0, 160)}…` : preview
                  })()}
                </p>
                <div className="flex flex-wrap gap-3 text-sm">
                  <span className="px-3 py-1.5 bg-surface2 border border-line rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-fg3"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                      />
                    </svg>
                    <span className="text-fg2">
                      ETA:{' '}
                      {baseProposal.eta === '0'
                        ? 'Not queued'
                        : new Date(Number(baseProposal.eta) * 1000).toLocaleString()}
                    </span>
                  </span>
                  <span className="px-3 py-1.5 bg-surface2 border border-line rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-fg3"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M13 10V3L4 14h7v7l9-11h-7z"
                      />
                    </svg>
                    <span className="text-fg2">Chains: {baseProposal.chains.join(', ')}</span>
                  </span>
                  {baseStatus === 'PENDING' &&
                    effectiveStatus === 'PENDING' &&
                    timing.timeRemaining > 0 && (
                      <span className="px-3 py-1.5 bg-warn-bg rounded-full flex items-center space-x-2 text-warn">
                        <svg
                          className="w-4 h-4"
                          fill="none"
                          stroke="currentColor"
                          viewBox="0 0 24 24"
                        >
                          <path
                            strokeLinecap="round"
                            strokeLinejoin="round"
                            strokeWidth={2}
                            d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
                          />
                        </svg>
                        <span className="text-sm">
                          Voting starts in: {Math.floor(timing.timeRemaining / 3600)}h{' '}
                          {Math.floor((timing.timeRemaining % 3600) / 60)}m
                        </span>
                      </span>
                    )}
                  {baseStatus === 'PENDING' && effectiveStatus === 'ACTIVE' && (
                    <span className="px-3 py-1.5 bg-ok-bg rounded-full flex items-center space-x-2 text-ok">
                      <svg
                        className="w-4 h-4"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
                        />
                      </svg>
                      <span className="text-sm font-medium">Voting is now active!</span>
                    </span>
                  )}
                </div>

                {/* Voting Section for Active Proposals */}
                {effectiveStatus === 'ACTIVE' && (
                  <div className="border-t border-line pt-4 mt-4">
                    <div className="space-y-4">
                      {/* Current Vote Counts */}
                      {proposalData[baseProposal.id]?.votes && (
                        <div className="bg-surface2 border border-line rounded-lg p-3.5">
                          <h4 className="text-sm font-medium text-fg2 mb-3">Current Votes</h4>
                          <div className="grid grid-cols-3 gap-4">
                            <div className="text-center">
                              <div className="font-mono text-base font-medium text-ok">
                                {(
                                  Number(proposalData[baseProposal.id].votes.forVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-fg3">For</div>
                            </div>
                            <div className="text-center">
                              <div className="font-mono text-base font-medium text-crit">
                                {(
                                  Number(proposalData[baseProposal.id].votes.againstVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-fg3">Against</div>
                            </div>
                            <div className="text-center">
                              <div className="text-lg font-bold text-fg3">
                                {(
                                  Number(proposalData[baseProposal.id].votes.abstainVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-fg3">Abstain</div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* User Already Voted Notice */}
                      {isConnected && proposalData[baseProposal.id]?.hasVoted === true && (
                        <div className="bg-ok-bg border border-ok/20 rounded-lg p-3">
                          <div className="flex items-center space-x-2">
                            <svg
                              className="w-5 h-5 text-ok"
                              fill="none"
                              stroke="currentColor"
                              viewBox="0 0 24 24"
                            >
                              <path
                                strokeLinecap="round"
                                strokeLinejoin="round"
                                strokeWidth={2}
                                d="M5 13l4 4L19 7"
                              />
                            </svg>
                            <p className="text-sm text-ok font-medium">
                              You have already voted on this proposal.
                            </p>
                          </div>
                        </div>
                      )}

                      {/* Voting Buttons */}
                      {isConnected &&
                        votingPower !== undefined &&
                        votingPower > 0n &&
                        proposalData[baseProposal.id]?.hasVoted !== true && (
                          <div className="space-y-3">
                            <h4 className="text-sm font-medium text-fg2">Cast Your Vote</h4>
                            <div className="flex gap-3">
                              <button
                                onClick={() => handleVote(baseProposal.id, 1 as VoteSupport)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 h-[34px] px-3 rounded-lg text-white text-xs font-semibold transition-colors ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-surface3 text-fg3 cursor-not-allowed'
                                    : 'bg-ok hover:brightness-110'
                                }`}
                              >
                                {votingProposals.has(baseProposal.id) || isPending ? (
                                  <div className="flex items-center justify-center space-x-2">
                                    <svg
                                      className="w-4 h-4 animate-spin"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                                      />
                                    </svg>
                                    <span>Voting...</span>
                                  </div>
                                ) : (
                                  'Vote For'
                                )}
                              </button>
                              <button
                                onClick={() => handleVote(baseProposal.id, 0 as VoteSupport)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 h-[34px] px-3 rounded-lg text-white text-xs font-semibold transition-colors ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-surface3 text-fg3 cursor-not-allowed'
                                    : 'bg-crit hover:brightness-110'
                                }`}
                              >
                                {votingProposals.has(baseProposal.id) || isPending ? (
                                  <div className="flex items-center justify-center space-x-2">
                                    <svg
                                      className="w-4 h-4 animate-spin"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                                      />
                                    </svg>
                                    <span>Voting...</span>
                                  </div>
                                ) : (
                                  'Vote Against'
                                )}
                              </button>
                              <button
                                onClick={() => handleVote(baseProposal.id, 2 as VoteSupport)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 h-[34px] px-3 rounded-lg text-white text-xs font-semibold transition-colors ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-surface3 text-fg3 cursor-not-allowed'
                                    : 'bg-surface3 hover:bg-surface2 text-fg'
                                }`}
                              >
                                {votingProposals.has(baseProposal.id) || isPending ? (
                                  <div className="flex items-center justify-center space-x-2">
                                    <svg
                                      className="w-4 h-4 animate-spin"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                                      />
                                    </svg>
                                    <span>Voting...</span>
                                  </div>
                                ) : (
                                  'Abstain'
                                )}
                              </button>
                            </div>
                          </div>
                        )}

                      {/* Show voting buttons even when data is loading, but user has wallet connected */}
                      {isConnected && votingPower === undefined && (
                        <div className="space-y-3">
                          <h4 className="text-sm font-medium text-fg2">Cast Your Vote</h4>
                          <div className="bg-info-bg border border-info/20 rounded-lg p-3">
                            <p className="text-sm text-info">Loading voting data...</p>
                          </div>
                        </div>
                      )}

                      {isConnected &&
                        votingPower !== undefined &&
                        (!votingPower || votingPower === BigInt(0)) && (
                          <div className="bg-warn-bg border border-warn/20 rounded-lg p-3">
                            <p className="text-sm text-warn">
                              You need SUMR tokens and voting power to participate in governance.
                            </p>
                          </div>
                        )}

                      {!isConnected && (
                        <div className="bg-info-bg border border-info/20 rounded-lg p-3">
                          <p className="text-sm text-info">
                            Connect your wallet to participate in governance voting.
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>

              <div className="space-y-3 pt-4 border-t border-line">
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-medium text-fg2">Cross-Chain Proposals</h4>
                  <span className="text-xs text-fg3">{crossChainProposals.length} proposals</span>
                </div>
                {crossChainProposals.length === 0 ? (
                  <div className="text-fg3 italic bg-surface3 p-4 rounded-lg">
                    <p className="text-center mb-3">No cross-chain proposals found</p>
                    {baseProposal.chains && baseProposal.chains.length > 1 ? (
                      <div className="space-y-2">
                        <p className="text-sm font-medium text-fg2">
                          This proposal will affect chains:
                        </p>
                        <div className="flex flex-wrap gap-2 justify-center">
                          {baseProposal.chains.map((chain) => (
                            <span
                              key={chain}
                              className="px-2.5 py-0.5 bg-info-bg text-info rounded-full text-xs font-medium"
                            >
                              {chain.charAt(0).toUpperCase() + chain.slice(1)}
                            </span>
                          ))}
                        </div>
                        {baseProposal.targets && baseProposal.targets.length > 0 && (
                          <div className="mt-3 pt-2 border-t border-line">
                            <p className="text-xs font-medium text-fg2 mb-1">Target contracts:</p>
                            <div className="space-y-1">
                              {baseProposal.targets.slice(0, 3).map((target, index) => (
                                <div
                                  key={index}
                                  className="text-xs text-fg2 font-mono bg-surface3 px-2 py-1 rounded"
                                >
                                  {target}
                                </div>
                              ))}
                              {baseProposal.targets.length > 3 && (
                                <p className="text-xs text-fg3">
                                  ... and {baseProposal.targets.length - 3} more contracts
                                </p>
                              )}
                            </div>
                          </div>
                        )}
                        <p className="text-xs text-fg2 mt-2 text-center">
                          Cross-chain proposals will be created after execution
                        </p>
                      </div>
                    ) : baseProposal.chains && baseProposal.chains.length === 1 ? (
                      <p className="text-sm text-center">
                        This proposal only affects{' '}
                        <span className="font-medium">{baseProposal.chains[0]}</span> chain
                      </p>
                    ) : (
                      <p className="text-sm text-center">
                        This proposal may not have cross-chain components
                      </p>
                    )}
                  </div>
                ) : (
                  <div className="grid gap-3">
                    {crossChainProposals.map((ccp) => {
                      const ccpStatus = getCrossChainProposalStatus(ccp)
                      const eta = Number(ccp.eta)
                      const currentTimestamp = Math.floor(Date.now() / 1000)
                      const timeUntilReady = eta > 0 ? eta - currentTimestamp : 0

                      return (
                        <div
                          key={ccp.id}
                          className="border border-line pl-3.5 py-3 bg-surface2 rounded-lg"
                        >
                          <div className="flex flex-wrap gap-3 items-center justify-between">
                            <div className="flex flex-wrap gap-3 items-center">
                              <span className="font-medium text-fg flex items-center space-x-2 text-sm">
                                <svg
                                  className="w-4 h-4"
                                  fill="none"
                                  stroke="currentColor"
                                  viewBox="0 0 24 24"
                                >
                                  <path
                                    strokeLinecap="round"
                                    strokeLinejoin="round"
                                    strokeWidth={2}
                                    d="M13 10V3L4 14h7v7l9-11h-7z"
                                  />
                                </svg>
                                <span>Chain: {ccp.chainId}</span>
                              </span>
                              <span
                                className={`px-3 py-1 rounded-full text-sm ${
                                  ccpStatus === 'Executed'
                                    ? 'bg-ok-bg text-ok'
                                    : ccpStatus === 'Ready'
                                      ? 'bg-warn-bg text-warn'
                                      : ccpStatus === 'Queued'
                                        ? 'bg-warn-bg text-warn'
                                        : ccpStatus === 'Pending'
                                          ? 'bg-info-bg text-info'
                                          : 'bg-surface3 text-fg3'
                                }`}
                              >
                                {ccpStatus}
                              </span>
                              {eta > 0 && (
                                <div className="flex items-center space-x-2 text-sm">
                                  {ccpStatus === 'Queued' ? (
                                    <span className="text-warn">
                                      Ready in: {Math.floor(timeUntilReady / 3600)}h{' '}
                                      {Math.floor((timeUntilReady % 3600) / 60)}m
                                    </span>
                                  ) : ccpStatus === 'Ready' ? (
                                    <span className="text-warn">
                                      Ready since: {new Date(eta * 1000).toLocaleString()}
                                    </span>
                                  ) : null}
                                </div>
                              )}
                            </div>
                            {(ccpStatus === 'Ready' || ccpStatus === 'Pending') && (
                              <button
                                onClick={() => handleExecuteProposal(ccp)}
                                disabled={executingProposals.has(ccp.id) || isPending}
                                className={`h-[30px] px-3 text-white text-xs font-semibold rounded-lg transition-colors flex items-center space-x-1.5 ${
                                  executingProposals.has(ccp.id) || isPending
                                    ? 'bg-surface3 text-fg3 cursor-not-allowed'
                                    : 'bg-brand-pink hover:brightness-110'
                                }`}
                              >
                                {executingProposals.has(ccp.id) || isPending ? (
                                  <>
                                    <svg
                                      className="w-4 h-4 animate-spin"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                                      />
                                    </svg>
                                    <span>Executing...</span>
                                  </>
                                ) : (
                                  <>
                                    <svg
                                      className="w-4 h-4"
                                      fill="none"
                                      stroke="currentColor"
                                      viewBox="0 0 24 24"
                                    >
                                      <path
                                        strokeLinecap="round"
                                        strokeLinejoin="round"
                                        strokeWidth={2}
                                        d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                                      />
                                    </svg>
                                    <span>Execute</span>
                                  </>
                                )}
                              </button>
                            )}
                          </div>
                          <div className="mt-2 space-y-1">
                            <p className="text-xs text-fg3 font-mono">ID: {ccp.id}</p>
                            <p className="text-xs text-fg3 font-mono">Salt: {ccp.salt}</p>
                            {eta > 0 && (
                              <p className="text-xs text-fg3">
                                ETA: {new Date(eta * 1000).toLocaleString()}
                              </p>
                            )}
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
      </div>
    </div>
  )
}
