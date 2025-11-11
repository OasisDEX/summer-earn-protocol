import React, { useEffect, useState } from 'react'
import { ethers } from 'ethers'
import { useAccount, useSwitchChain, useWriteContract } from 'wagmi'

import { calculateProposalTiming } from '@/utils/timing'

import config from '../config/index.json'
import { useMultipleProposalVoting } from '../hooks/useProposalVoting'
import { CrossChainProposal, fetchAllProposals, ProposalWithCrossChain } from '../services/subgraph'
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

// Governor ABI for execute and voting functions
const GOVERNOR_ABI = [
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'execute',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'descriptionHash', type: 'bytes32' },
    ],
    name: 'queue',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    name: 'castVote',
    outputs: [{ name: 'balance', type: 'uint256' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    name: 'proposalVotes',
    outputs: [
      { name: 'againstVotes', type: 'uint256' },
      { name: 'forVotes', type: 'uint256' },
      { name: 'abstainVotes', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'account', type: 'address' },
    ],
    name: 'hasVoted',
    outputs: [{ name: '', type: 'bool' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const

// Chain ID to network name mapping
const CHAIN_ID_TO_NETWORK: Record<string, keyof typeof config> = {
  '1': 'mainnet',
  '8453': 'base',
  '42161': 'arbitrum',
  '146': 'sonic',
}

// Vote types from OpenZeppelin GovernorCountingSimple
enum VoteType {
  Against = 0,
  For = 1,
  Abstain = 2,
}

// Helper function to calculate effective proposal status
const getEffectiveProposalStatus = (proposal: { status: string; createdAt: string }) => {
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
  const { switchChain } = useSwitchChain()

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

    const proposalChainId = parseInt(proposal.chainId)
    const networkName = CHAIN_ID_TO_NETWORK[proposal.chainId]

    if (!networkName) {
      alert(`Unsupported chain ID: ${proposal.chainId}`)
      return
    }

    // Get timelock address from config
    const timelockAddress = config[networkName]?.deployedContracts?.gov?.timelock?.address
    if (!timelockAddress) {
      alert(`Timelock address not found for chain ${networkName}`)
      return
    }

    try {
      setExecutingProposals((prev) => new Set(prev).add(proposal.id))

      // Switch chain if needed
      if (chainId !== proposalChainId) {
        await switchChain({ chainId: proposalChainId })
      }

      // Convert values from string to bigint
      const values = proposal.values.map((v) => BigInt(v))

      // Execute the proposal
      await writeContract({
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
        await switchChain({ chainId: 8453 })
      }

      // Create description hash
      const descriptionHash = ethers.keccak256(ethers.toUtf8Bytes(proposal.description))

      // Execute the proposal
      await writeContract({
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
        await switchChain({ chainId: 8453 })
      }

      // Create description hash
      const descriptionHash = ethers.keccak256(ethers.toUtf8Bytes(proposal.description))

      // Queue the proposal

      writeContract({
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

      // Refresh proposals after queueing
      setTimeout(() => {
        loadProposals()
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

  const handleVote = async (proposalId: string, support: VoteType) => {
    if (!isConnected || !address) {
      alert('Please connect your wallet first')
      return
    }

    const governorAddress = config.base?.deployedContracts?.gov?.summerGovernor?.address
    if (!governorAddress) {
      alert('Governor address not found for Base network')
      return
    }

    try {
      setVotingProposals((prev) => new Set(prev).add(proposalId))

      // Switch to Base if needed
      if (chainId !== 8453) {
        await switchChain({ chainId: 8453 })
      }

      // Cast the vote
      await writeContract({
        address: governorAddress as `0x${string}`,
        abi: GOVERNOR_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support],
      })

      console.log(`Successfully voted ${VoteType[support]} on proposal ${proposalId}`)

      // Refresh voting data after voting
      setTimeout(() => {
        refetchVotingData()
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

  const loadProposals = async () => {
    try {
      const data = await fetchAllProposals()
      setProposals(data)
      filterProposals(data, selectedStatuses)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load proposals')
    } finally {
      setLoading(false)
    }
  }

  const getCrossChainProposalStatus = (proposal: CrossChainProposal): ProposalStatus => {
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
  }

  const filterProposals = (proposals: ProposalWithCrossChain[], statuses: ProposalStatus[]) => {
    const filtered = proposals.filter((proposal) => {
      // Get the effective status for filtering
      const effectiveStatus = getEffectiveProposalStatus(proposal.baseProposal)
      const currentTimestamp = Math.floor(Date.now() / 1000)
      const baseEta = Number(proposal.baseProposal.eta)
      const isBaseReady = effectiveStatus === 'QUEUED' && baseEta > 0 && currentTimestamp >= baseEta

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
  }

  useEffect(() => {
    loadProposals()
  }, [])

  useEffect(() => {
    filterProposals(proposals, selectedStatuses)
  }, [selectedStatuses])

  if (loading)
    return (
      <div className="flex justify-center items-center min-h-[200px]">
        <div className="animate-pulse flex flex-col items-center space-y-4">
          <div className="h-8 w-32 bg-gray-200 dark:bg-gray-700 rounded"></div>
          <div className="h-4 w-24 bg-gray-200 dark:bg-gray-700 rounded"></div>
        </div>
      </div>
    )
  if (error)
    return (
      <div className="text-red-500 dark:text-red-400 p-6 border border-red-200 dark:border-red-800 rounded-lg bg-red-50 dark:bg-red-900/20">
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
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <h2 className="text-3xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
          Cross-Chain Proposals
        </h2>
        <div className="text-sm text-gray-500 dark:text-gray-400">
          Total Proposals: {filteredProposals.length}
        </div>
      </div>

      <div className="space-y-4">
        <ProposalFilter selectedStatuses={selectedStatuses} onStatusChange={setSelectedStatuses} />

        {isConnected && votingPower !== undefined && (
          <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-semibold text-blue-900 dark:text-blue-100">
                Your Voting Power
              </h3>
              <span className="text-2xl font-bold text-blue-700 dark:text-blue-300">
                {(Number(votingPower) / 1e18).toLocaleString(undefined, {
                  maximumFractionDigits: 2,
                })}{' '}
                SUMR
              </span>
            </div>
            <p className="text-sm text-blue-600 dark:text-blue-400 mt-1">
              This is your current voting power including decay adjustments
            </p>
          </div>
        )}
      </div>

      <div className="grid gap-6">
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
              className="group border border-gray-200 dark:border-gray-700 rounded-xl p-6 space-y-4 bg-white dark:bg-gray-800 shadow-sm hover:shadow-lg transition-all duration-300 ease-in-out"
            >
              <div className="space-y-4">
                <div className="flex justify-between items-start">
                  <div className="space-y-1">
                    <h3 className="text-xl font-semibold text-gray-900 dark:text-white">
                      Proposal #{baseProposal.id}
                    </h3>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      Created on{' '}
                      {new Date(Number(baseProposal.createdAt) * 1000).toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`px-4 py-1.5 rounded-full text-sm font-medium transition-colors duration-200 ${
                        effectiveStatus === 'EXECUTED'
                          ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                          : effectiveStatus === 'SUCCEEDED'
                            ? 'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-800 dark:text-emerald-300'
                            : isBaseReady
                              ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300'
                              : isBaseQueued
                                ? 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300'
                                : effectiveStatus === 'ACTIVE'
                                  ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300'
                                  : 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300'
                      }`}
                    >
                      {isBaseReady ? 'Ready' : effectiveStatus}
                    </span>
                    {effectiveStatus === 'SUCCEEDED' && (
                      <button
                        onClick={() => handleQueueBaseProposal(baseProposal)}
                        disabled={executingProposals.has(baseProposal.id) || isPending}
                        className={`px-4 py-1.5 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                          executingProposals.has(baseProposal.id) || isPending
                            ? 'bg-gray-400 cursor-not-allowed'
                            : 'bg-blue-600 hover:bg-blue-700'
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
                        className={`px-4 py-1.5 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                          executingProposals.has(baseProposal.id) ||
                          isPending ||
                          (!isBaseReady && isBaseQueued)
                            ? 'bg-gray-400 cursor-not-allowed'
                            : 'bg-blue-600 hover:bg-blue-700'
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
                <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
                  <PhaseIndicator timing={timing} variant="default" />
                </div>

                <p className="text-gray-600 dark:text-gray-300 text-sm leading-relaxed bg-gray-50 dark:bg-gray-700 p-4 rounded-lg">
                  {baseProposal.description.slice(0, 100)}
                  {baseProposal.description.length > 100 && '...'}
                </p>
                <div className="flex flex-wrap gap-3 text-sm">
                  <span className="px-4 py-2 bg-gray-50 dark:bg-gray-700 rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-gray-500 dark:text-gray-400"
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
                    <span className="text-gray-700 dark:text-gray-300">
                      ETA:{' '}
                      {baseProposal.eta === '0'
                        ? 'Not queued'
                        : new Date(Number(baseProposal.eta) * 1000).toLocaleString()}
                    </span>
                  </span>
                  <span className="px-4 py-2 bg-gray-50 dark:bg-gray-700 rounded-full flex items-center space-x-2">
                    <svg
                      className="w-4 h-4 text-gray-500 dark:text-gray-400"
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
                    <span className="text-gray-700 dark:text-gray-300">
                      Chains: {baseProposal.chains.join(', ')}
                    </span>
                  </span>
                  {baseStatus === 'PENDING' &&
                    effectiveStatus === 'PENDING' &&
                    timing.timeRemaining > 0 && (
                      <span className="px-4 py-2 bg-amber-50 dark:bg-amber-900/30 rounded-full flex items-center space-x-2 text-amber-800 dark:text-amber-300">
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
                    <span className="px-4 py-2 bg-green-50 dark:bg-green-900/30 rounded-full flex items-center space-x-2 text-green-800 dark:text-green-300">
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
                  <div className="border-t border-gray-100 dark:border-gray-700 pt-4 mt-4">
                    <div className="space-y-4">
                      {/* Current Vote Counts */}
                      {proposalData[baseProposal.id]?.votes && (
                        <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
                          <h4 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                            Current Votes
                          </h4>
                          <div className="grid grid-cols-3 gap-4">
                            <div className="text-center">
                              <div className="text-lg font-bold text-green-600 dark:text-green-400">
                                {(
                                  Number(proposalData[baseProposal.id].votes.forVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-gray-600 dark:text-gray-400">For</div>
                            </div>
                            <div className="text-center">
                              <div className="text-lg font-bold text-red-600 dark:text-red-400">
                                {(
                                  Number(proposalData[baseProposal.id].votes.againstVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-gray-600 dark:text-gray-400">
                                Against
                              </div>
                            </div>
                            <div className="text-center">
                              <div className="text-lg font-bold text-gray-600 dark:text-gray-400">
                                {(
                                  Number(proposalData[baseProposal.id].votes.abstainVotes) / 1e18
                                ).toLocaleString(undefined, {
                                  maximumFractionDigits: 0,
                                })}
                              </div>
                              <div className="text-sm text-gray-600 dark:text-gray-400">
                                Abstain
                              </div>
                            </div>
                          </div>
                        </div>
                      )}

                      {/* User Already Voted Notice */}
                      {isConnected && proposalData[baseProposal.id]?.hasVoted === true && (
                        <div className="bg-green-50 border border-green-200 rounded-lg p-3">
                          <div className="flex items-center space-x-2">
                            <svg
                              className="w-5 h-5 text-green-600"
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
                            <p className="text-sm text-green-800 font-medium">
                              You have already voted on this proposal.
                            </p>
                          </div>
                        </div>
                      )}

                      {/* Voting Buttons */}
                      {isConnected &&
                        votingPower &&
                        votingPower > 0 &&
                        proposalData[baseProposal.id]?.hasVoted !== true && (
                          <div className="space-y-3">
                            <h4 className="text-sm font-medium text-gray-700">Cast Your Vote</h4>
                            <div className="flex gap-3">
                              <button
                                onClick={() => handleVote(baseProposal.id, VoteType.For)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 py-2 px-4 rounded-lg text-white font-medium transition-colors duration-200 ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-green-600 hover:bg-green-700'
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
                                onClick={() => handleVote(baseProposal.id, VoteType.Against)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 py-2 px-4 rounded-lg text-white font-medium transition-colors duration-200 ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-red-600 hover:bg-red-700'
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
                                onClick={() => handleVote(baseProposal.id, VoteType.Abstain)}
                                disabled={votingProposals.has(baseProposal.id) || isPending}
                                className={`flex-1 py-2 px-4 rounded-lg text-white font-medium transition-colors duration-200 ${
                                  votingProposals.has(baseProposal.id) || isPending
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-gray-600 hover:bg-gray-700'
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
                          <h4 className="text-sm font-medium text-gray-700">Cast Your Vote</h4>
                          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                            <p className="text-sm text-blue-800">Loading voting data...</p>
                          </div>
                        </div>
                      )}

                      {isConnected &&
                        votingPower !== undefined &&
                        (!votingPower || votingPower === BigInt(0)) && (
                          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-3">
                            <p className="text-sm text-yellow-800">
                              You need SUMR tokens and voting power to participate in governance.
                            </p>
                          </div>
                        )}

                      {!isConnected && (
                        <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
                          <p className="text-sm text-blue-800">
                            Connect your wallet to participate in governance voting.
                          </p>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>

              <div className="space-y-3 pt-4 border-t border-gray-100 dark:border-gray-700">
                <div className="flex items-center justify-between">
                  <h4 className="text-lg font-medium text-gray-700 dark:text-gray-300">
                    Cross-Chain Proposals
                  </h4>
                  <span className="text-sm text-gray-500 dark:text-gray-400">
                    {crossChainProposals.length} proposals
                  </span>
                </div>
                {crossChainProposals.length === 0 ? (
                  <div className="text-gray-500 dark:text-gray-400 italic bg-gray-50 dark:bg-gray-700 p-4 rounded-lg">
                    <p className="text-center mb-3">No cross-chain proposals found</p>
                    {baseProposal.chains && baseProposal.chains.length > 1 ? (
                      <div className="space-y-2">
                        <p className="text-sm font-medium text-gray-700 dark:text-gray-300">
                          This proposal will affect chains:
                        </p>
                        <div className="flex flex-wrap gap-2 justify-center">
                          {baseProposal.chains.map((chain) => (
                            <span
                              key={chain}
                              className="px-3 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300 rounded-full text-sm font-medium"
                            >
                              {chain.charAt(0).toUpperCase() + chain.slice(1)}
                            </span>
                          ))}
                        </div>
                        {baseProposal.targets && baseProposal.targets.length > 0 && (
                          <div className="mt-3 pt-2 border-t border-gray-200">
                            <p className="text-xs font-medium text-gray-700 mb-1">
                              Target contracts:
                            </p>
                            <div className="space-y-1">
                              {baseProposal.targets.slice(0, 3).map((target, index) => (
                                <div
                                  key={index}
                                  className="text-xs text-gray-600 font-mono bg-gray-100 px-2 py-1 rounded"
                                >
                                  {target}
                                </div>
                              ))}
                              {baseProposal.targets.length > 3 && (
                                <p className="text-xs text-gray-500">
                                  ... and {baseProposal.targets.length - 3} more contracts
                                </p>
                              )}
                            </div>
                          </div>
                        )}
                        <p className="text-xs text-gray-600 mt-2 text-center">
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
                          className="border-l-4 border-blue-500 pl-4 py-3 bg-blue-50 dark:bg-blue-900/20 rounded-r-lg hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors duration-200"
                        >
                          <div className="flex flex-wrap gap-3 items-center justify-between">
                            <div className="flex flex-wrap gap-3 items-center">
                              <span className="font-medium text-blue-900 dark:text-blue-100 flex items-center space-x-2">
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
                                    ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                                    : ccpStatus === 'Ready'
                                      ? 'bg-orange-100 dark:bg-orange-900/30 text-orange-800 dark:text-orange-300'
                                      : ccpStatus === 'Queued'
                                        ? 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300'
                                        : ccpStatus === 'Pending'
                                          ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300'
                                          : 'bg-gray-100 dark:bg-gray-700 text-gray-800 dark:text-gray-300'
                                }`}
                              >
                                {ccpStatus}
                              </span>
                              {eta > 0 && (
                                <div className="flex items-center space-x-2 text-sm">
                                  {ccpStatus === 'Queued' ? (
                                    <span className="text-yellow-700 dark:text-yellow-300">
                                      Ready in: {Math.floor(timeUntilReady / 3600)}h{' '}
                                      {Math.floor((timeUntilReady % 3600) / 60)}m
                                    </span>
                                  ) : ccpStatus === 'Ready' ? (
                                    <span className="text-orange-700 dark:text-orange-300">
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
                                className={`px-4 py-2 text-white text-sm font-medium rounded-lg transition-colors duration-200 flex items-center space-x-2 ${
                                  executingProposals.has(ccp.id) || isPending
                                    ? 'bg-gray-400 cursor-not-allowed'
                                    : 'bg-blue-600 hover:bg-blue-700'
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
                            <p className="text-sm text-blue-700 dark:text-blue-300 font-mono">
                              ID: {ccp.id}
                            </p>
                            <p className="text-sm text-blue-700 dark:text-blue-300 font-mono">
                              Salt: {ccp.salt}
                            </p>
                            {eta > 0 && (
                              <p className="text-sm text-blue-700 dark:text-blue-300">
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
